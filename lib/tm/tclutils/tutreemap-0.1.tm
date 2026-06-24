# tutreemap-0.1.tm -- parse a Mermaid `treemap-beta` block and render it as a
# squarified treemap (area-proportional nested rectangles) to SVG or PNG through
# the pure-Tcl backends (tusvg / tupngdraw) -- no browser. Like `tupie` /
# `tukanban` / `tupacket`, this is NOT a node-edge graph: it renders directly and
# is reached through the `tclutils::tuflow` facade (`tuflow::toSvg` / `toPng`),
# which dispatches `treemap-beta` here.
#
#   set m [::tclutils::tutreemap::parse $text]
#   ::tclutils::tutreemap::writeSvg $m out.svg
#   set png [::tclutils::tutreemap::toPng $m -scale 3]
#
# Supported syntax (Mermaid subset):
#   treemap-beta                 -> header (also bare `treemap`)
#   "Section"                    -> a branch (parent); value = sum of children
#   "Leaf": <value>              -> a leaf with a numeric value
#   <indentation>                -> defines the hierarchy (deeper = child)
#   "Leaf":::class / classDef    -> styling is parsed off and IGNORED (v1)
#   %% ...                       -> comment
#
# Areas are proportional to leaf values; a branch's area is the sum of its
# leaves. Tiling uses the squarify algorithm (Bruls/Huizing/van Wijk) so cells
# stay close to square. Each branch below the root draws a header bar with its
# name; leaves show name + value when there is room. Colours come from a fixed
# palette per top-level section, lightened with depth so the hierarchy reads.
#
# v1 limitations (honest):
#   - styling (`:::class`, `classDef`, theme, valueFormat) is ignored
#   - labels are clipped (not wrapped/shrunk); tiny cells show no label
#   - negative values are dropped (treemaps need non-negative areas)
#   - a node given a value AND children is treated as a branch (children win)
#
# Namespace: ::tclutils::tutreemap   Package: tclutils::tutreemap 0.1
# Errors:    {TCLUTILS TUTREEMAP <REASON>}   REASON in EMPTY|VALUE|ARG|FONT

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tutreemap {
    namespace export parse toSvg toPng writeSvg writePng

    variable palette {
        #4e79a7 #f28e2b #e15759 #76b7b2 #59a14f
        #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac
    }
    variable HEADER 16   ;# header-bar height for branch nodes (logical units)
    variable GAP     2   ;# gap between sibling cells
}

# --- helpers -----------------------------------------------------------------

proc ::tclutils::tutreemap::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUTREEMAP $reason] $msg
}

proc ::tclutils::tutreemap::_indent {raw} {
    set n 0
    foreach ch [split $raw ""] {
        if {$ch eq " "} { incr n } elseif {$ch eq "\t"} { incr n 4 } else break
    }
    return $n
}

# Mix a #rrggbb colour toward target (0 = black, 255 = white) by frac (0..1).
proc ::tclutils::tutreemap::_mix {hex target frac} {
    if {![regexp {^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$} $hex -> r g b]} {
        return $hex
    }
    scan $r %x r; scan $g %x g; scan $b %x b
    set r [expr {int($r + ($target-$r)*$frac)}]
    set g [expr {int($g + ($target-$g)*$frac)}]
    set b [expr {int($b + ($target-$b)*$frac)}]
    return [format "#%02x%02x%02x" $r $g $b]
}
proc ::tclutils::tutreemap::_lighten {hex frac} { _mix $hex 255 $frac }
proc ::tclutils::tutreemap::_darken  {hex frac} { _mix $hex 0   $frac }

proc ::tclutils::tutreemap::_drawText {c gfont scale x y str color} {
    if {$gfont eq "" || $str eq ""} {
        $c text $x $y $str -scale $scale -color $color
        return
    }
    set cellH   [expr {8.0 * $scale}]
    set targetW [expr {[string length $str] * 6.0 * $scale}]
    set upm [$gfont get unitsPerEm]
    set asc [$gfont get ascender]
    set dsc [$gfont get descender]
    set span [expr {$asc - $dsc}]
    set adv 0.0
    foreach ch [split $str ""] {
        set adv [expr {$adv + [$gfont gget [$gfont unicode2glyphIndex $ch] advanceWidth]}]
    }
    if {$span <= 0 || $upm <= 0 || $adv <= 0} {
        $c text $x $y $str -scale $scale -color $color
        return
    }
    set sy [expr {$cellH / double($span)}]
    set sx [expr {$targetW / ($adv * $sy)}]
    set baseline [expr {$y + $asc * $sy}]
    set pen 0.0
    foreach ch [split $str ""] {
        set gi [$gfont unicode2glyphIndex $ch]
        set aw [$gfont gget $gi advanceWidth]
        if {$gi != 0} {
            set g [$gfont glyph $gi]
            set contours {}
            foreach cont [$g onUniformSteps 6 "at"] {
                set flat {}
                foreach pt $cont {
                    lassign $pt fx fy
                    lappend flat [expr {$x + ($pen + $fx) * $sy * $sx}] \
                                 [expr {$baseline - $fy * $sy}]
                }
                if {[llength $flat] >= 6} { lappend contours $flat }
            }
            if {[llength $contours]} { $c fillcontours $contours -color $color -rule nonzero }
            $g destroy
        }
        set pen [expr {$pen + $aw}]
    }
}

proc ::tclutils::tutreemap::_clip {c scale str maxW} {
    set txt $str
    while {$txt ne "" && [$c textwidth $txt -scale $scale] > $maxW} {
        set txt [string range $txt 0 end-1]
    }
    return $txt
}

proc ::tclutils::tutreemap::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 640 -height 400 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        _err ARG "-scale must be a positive integer"
    }
    return $o
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tutreemap::parse {text} {
    # Build the tree with id-keyed arrays, then assemble into a nested dict.
    array set NAME {}; array set VAL {}; array set KIDS {}
    set NAME(0) ""; set VAL(0) 0; set KIDS(0) {}
    set nextId 1
    set sawHeader 0
    set stack {}    ;# list of {indent id}, innermost last

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {!$sawHeader} {
            if {[regexp -nocase {^treemap(-beta)?\M} $line]} { set sawHeader 1; continue }
            _err EMPTY "not a treemap diagram (missing header)"
        }
        # styling directives we ignore
        if {[regexp {^classDef\M} $line] || [regexp {^style\M} $line]} continue
        set ind [_indent $raw]
        # strip a :::class styling tag (may sit right after the name or at eol)
        regsub {:::[A-Za-z0-9_]+} $line "" line
        # "Name": value   (leaf)   or   "Name"   (branch)
        if {[regexp {^"([^"]*)"\s*:\s*([-+0-9.eE]+)\s*$} $line -> name val]} {
            if {![string is double -strict $val]} { _err VALUE "bad value for \"$name\": $val" }
            set isLeaf 1
        } elseif {[regexp {^"([^"]*)"\s*$} $line -> name]} {
            set isLeaf 0; set val 0
        } elseif {[regexp {^([^:]+?)\s*:\s*([-+0-9.eE]+)\s*$} $line -> name val]} {
            # tolerate unquoted leaf
            if {![string is double -strict $val]} { _err VALUE "bad value for $name: $val" }
            set name [string trim $name]; set isLeaf 1
        } elseif {[regexp {^([^":]+?)\s*$} $line -> name]} {
            set name [string trim $name]; set isLeaf 0; set val 0
        } else {
            _err VALUE "cannot parse treemap line: $line"
        }

        # find parent: pop while top indent >= this indent
        while {[llength $stack] && [lindex [lindex $stack end] 0] >= $ind} {
            set stack [lrange $stack 0 end-1]
        }
        set parent [expr {[llength $stack] ? [lindex [lindex $stack end] 1] : 0}]

        set id $nextId; incr nextId
        set NAME($id) $name
        set VAL($id) [expr {$isLeaf ? double($val) : 0}]
        set KIDS($id) {}
        lappend KIDS($parent) $id
        lappend stack [list $ind $id]
    }

    if {!$sawHeader} { _err EMPTY "not a treemap diagram (missing header)" }
    if {![llength $KIDS(0)]} { _err EMPTY "treemap diagram has no nodes" }

    # bottom-up value sums; assemble nested dict
    return [_assemble NAME VAL KIDS 0]
}

proc ::tclutils::tutreemap::_assemble {nameA valA kidsA id} {
    upvar 1 $nameA NAME $valA VAL $kidsA KIDS
    set children {}
    set sum 0.0
    foreach kid $KIDS($id) {
        set cn [_assemble $nameA $valA $kidsA $kid]
        set sum [expr {$sum + [dict get $cn value]}]
        lappend children $cn
    }
    set v [expr {[llength $KIDS($id)] ? $sum : $VAL($id)}]
    return [dict create name $NAME($id) value $v children $children]
}

# --- squarify ----------------------------------------------------------------

# worst aspect ratio of a row of areas laid along a strip of length `side`.
proc ::tclutils::tutreemap::_worst {row side} {
    set s 0.0; set rmax 0.0; set rmin 1e300
    foreach c $row {
        set a [lindex $c 1]
        set s [expr {$s + $a}]
        if {$a > $rmax} { set rmax $a }
        if {$a < $rmin} { set rmin $a }
    }
    if {$s <= 0 || $side <= 0} { return 1e300 }
    set s2 [expr {$s*$s}]; set w2 [expr {$side*$side}]
    return [expr {max($w2*$rmax/$s2, $s2/($w2*$rmin))}]
}

# place one finished row into the remaining rect; returns {placed nx ny nw nh}.
proc ::tclutils::tutreemap::_layoutRow {row rx ry rw rh} {
    set s 0.0; foreach c $row { set s [expr {$s + [lindex $c 1]}] }
    set placed {}
    if {$rw >= $rh} {
        set cw [expr {$rh > 0 ? $s/$rh : 0}]
        set yy $ry
        foreach c $row {
            set ih [expr {$cw > 0 ? [lindex $c 1]/$cw : 0}]
            lappend placed [list [lindex $c 0] $rx $yy $cw $ih]
            set yy [expr {$yy + $ih}]
        }
        return [list $placed [expr {$rx+$cw}] $ry [expr {$rw-$cw}] $rh]
    } else {
        set bh [expr {$rw > 0 ? $s/$rw : 0}]
        set xx $rx
        foreach c $row {
            set iw [expr {$bh > 0 ? [lindex $c 1]/$bh : 0}]
            lappend placed [list [lindex $c 0] $xx $ry $iw $bh]
            set xx [expr {$xx + $iw}]
        }
        return [list $placed $rx [expr {$ry+$bh}] $rw [expr {$rh-$bh}]]
    }
}

# squarify a list of {token value} into rect (x,y,w,h). Returns {token x y w h}.
proc ::tclutils::tutreemap::_squarify {items x y w h} {
    if {$w <= 0 || $h <= 0} { return {} }
    set total 0.0; foreach it $items { set total [expr {$total + [lindex $it 1]}] }
    if {$total <= 0} { return {} }
    set scale [expr {double($w)*$h/$total}]
    set scaled {}
    foreach it $items {
        set a [expr {[lindex $it 1]*$scale}]
        if {$a > 0} { lappend scaled [list [lindex $it 0] $a] }
    }
    set scaled [lsort -real -decreasing -index 1 $scaled]
    set result {}
    set rx $x; set ry $y; set rw $w; set rh $h
    set row {}
    set i 0; set n [llength $scaled]
    while {$i < $n} {
        set side [expr {min($rw,$rh)}]
        set c [lindex $scaled $i]
        if {![llength $row] || [_worst [concat $row [list $c]] $side] <= [_worst $row $side]} {
            lappend row $c
            incr i
        } else {
            lassign [_layoutRow $row $rx $ry $rw $rh] placed rx ry rw rh
            lappend result {*}$placed
            set row {}
        }
    }
    if {[llength $row]} {
        lassign [_layoutRow $row $rx $ry $rw $rh] placed rx ry rw rh
        lappend result {*}$placed
    }
    return $result
}

# --- draw --------------------------------------------------------------------

proc ::tclutils::tutreemap::_drawNode {c node x y w h depth col assigned gfont fs} {
    variable palette; variable HEADER; variable GAP
    set name [dict get $node name]
    set kids [dict get $node children]
    set np [llength $palette]
    set drawCol [expr {$col eq "" ? "#b7c2cd" : $col}]

    if {![llength $kids]} {
        # leaf cell
        $c rect $x $y [expr {$x+$w}] [expr {$y+$h}] -fill 1 -fillcolor $drawCol \
            -outline 1 -color white
        if {$w > 18*$fs && $h > 11*$fs} {
            _drawText $c $gfont $fs [expr {$x+3*$fs}] [expr {$y+3*$fs}] \
                [_clip $c $fs $name [expr {$w-6*$fs}]] #1a1a1a
            set val [dict get $node value]
            set vs [expr {$val == int($val) ? [expr {int($val)}] : $val}]
            if {$h > 22*$fs} {
                _drawText $c $gfont $fs [expr {$x+3*$fs}] [expr {$y+13*$fs}] \
                    [_clip $c $fs $vs [expr {$w-6*$fs}]] #555555
            }
        }
        return
    }

    # branch: optional header bar (not for the implicit root)
    set bx $x; set by $y; set bw $w; set bh $h
    set hdr [expr {$HEADER*$fs}]
    if {$depth > 0 && $h > $hdr+6*$fs && $w > 16*$fs} {
        $c rect $x $y [expr {$x+$w}] [expr {$y+$hdr}] -fill 1 \
            -fillcolor [_darken $drawCol 0.22] -outline 1 -color white
        _drawText $c $gfont $fs [expr {$x+3*$fs}] [expr {$y+2*$fs}] \
            [_clip $c $fs $name [expr {$w-6*$fs}]] white
        set by [expr {$y+$hdr}]; set bh [expr {$h-$hdr}]
    }

    set vals {}
    foreach k $kids { lappend vals [list $k [dict get $k value]] }
    set gap [expr {$GAP*$fs}]
    # assign the palette at the FIRST level that actually branches, so a tree
    # with a single root section still shows distinct section colours.
    set assignHere [expr {!$assigned && [llength $kids] > 1}]
    set i 0
    foreach r [_squarify $vals $bx $by $bw $bh] {
        lassign $r kid cx cy cw ch
        set gx [expr {$cx+$gap}]; set gy [expr {$cy+$gap}]
        set gw [expr {$cw-2*$gap}]; set gh [expr {$ch-2*$gap}]
        if {$gw <= 0 || $gh <= 0} { set gx $cx; set gy $cy; set gw $cw; set gh $ch }
        if {$gw <= 0 || $gh <= 0} { incr i; continue }
        if {$assignHere} {
            set kcol [lindex $palette [expr {$i % $np}]]; set kassigned 1
        } elseif {!$assigned} {
            set kcol ""; set kassigned 0            ;# single-child passthrough
        } else {
            set kcol [_lighten $col 0.14]; set kassigned 1
        }
        _drawNode $c $kid $gx $gy $gw $gh [expr {$depth+1}] $kcol $kassigned $gfont $fs
        incr i
    }
}

proc ::tclutils::tutreemap::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} { _err FONT "font file not found: $fontfile" }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""
    catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

proc ::tclutils::tutreemap::_draw {c model o gfont} {
    variable GAP
    set W [$c width]; set H [$c height]
    set fs [dict get $o -scale]
    set pad [expr {6*$fs}]
    _drawNode $c $model [expr {$pad}] [expr {$pad}] \
        [expr {$W-2*$pad}] [expr {$H-2*$pad}] 0 "" 0 $gfont $fs
}

# --- public render -----------------------------------------------------------

proc ::tclutils::tutreemap::toSvg {model args} {
    set o [_opts {*}$args]
    package require tclutils::tusvg 0.2
    set c [::tclutils::tusvg::new \
        -width [dict get $o -width] -height [dict get $o -height] -background white]
    _draw $c $model $o ""
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tutreemap::toPng {model args} {
    set o [_opts {*}$args]
    package require tclutils::tupngdraw
    set sc [dict get $o -scale]
    set c [::tclutils::tupngdraw::new \
        -width  [expr {[dict get $o -width]  * $sc}] \
        -height [expr {[dict get $o -height] * $sc}] -background white]
    catch {$c setantialias 1}
    set gf [_resolveFont $c [dict get $o -fontfile]]
    if {[catch {_draw $c $model $o $gf} err opt]} {
        catch {$gf destroy}; catch {$c destroy}
        return -options $opt $err
    }
    catch {$gf destroy}
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tutreemap::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tutreemap::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tutreemap 0.1
