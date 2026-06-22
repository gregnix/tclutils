# tusankey-0.1.tm -- parse and render a Mermaid `sankey-beta` block to SVG or
# PNG. A self-contained 2D renderer in the tuflow family (like tupie /
# tuxychart / tuquadrant): it has its own parser and draws onto the shared
# abstract canvas (tusvg / tupngdraw), so SVG and PNG output stay congruent.
#
# Syntax (Mermaid sankey-beta): the header line `sankey-beta` (or `sankey`)
# followed by CSV rows of exactly three columns `source,target,value`. Node
# names containing a comma are wrapped in double quotes; a literal double quote
# is written as a pair (""). Blank lines and `%%` comments are ignored. Nodes
# appear in first-seen order.
#
# Layout (v1): nodes are placed in columns by longest-path rank from the
# sources; each node's height is proportional to max(inflow, outflow); links
# are drawn as smooth bands whose width is proportional to the value, stacked at
# each node in link order. Cycles are handled best-effort (rank iteration is
# bounded). Link colour follows the source node (Mermaid `linkColor: source`).
#
# Namespace: ::tclutils::tusankey   Package: tclutils::tusankey 0.1
# Errors:    {TCLUTILS TUSANKEY <REASON>}   REASON in EMPTY | ARG | FONT

package require Tcl 8.6 9
package require tclutils::common 0.1

namespace eval ::tclutils::tusankey {
    namespace export parse toSvg toPng writeSvg writePng
    # node colour palette (cycled in first-seen order)
    variable palette {
        #4e79a7 #f28e2b #e15759 #76b7b2 #59a14f
        #edc948 #b07aa1 #ff9da7 #9c755f #bab0ab
    }
}

proc ::tclutils::tusankey::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUSANKEY $reason] $msg
}

# --- small helpers (shared shape with the other 2D renderers) ----------------

proc ::tclutils::tusankey::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 700 -height 400 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        _err ARG "-scale must be a positive integer"
    }
    return $o
}

proc ::tclutils::tusankey::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} { _err FONT "font file not found: $fontfile" }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""
    catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

# Lighten a #rrggbb colour toward white by fraction f (0..1).
proc ::tclutils::tusankey::_lighten {hex f} {
    if {![regexp {^#([0-9a-fA-F]{6})$} $hex -> h]} { return $hex }
    set r [scan [string range $h 0 1] %x]
    set g [scan [string range $h 2 3] %x]
    set b [scan [string range $h 4 5] %x]
    set r [expr {int($r + ($f * (255 - $r)))}]
    set g [expr {int($g + ($f * (255 - $g)))}]
    set b [expr {int($b + ($f * (255 - $b)))}]
    return [format "#%02x%02x%02x" $r $g $b]
}

# Draw text via the bitmap font, or as real outlines if a Glyphs font is given.
proc ::tclutils::tusankey::_drawText {c gfont scale x y str color} {
    if {$gfont eq "" || $str eq ""} {
        $c text $x $y $str -scale $scale -color $color
        return
    }
    set cellH   [expr {8.0 * $scale}]
    set targetW [expr {[string length $str] * 6.0 * $scale}]
    set upm  [$gfont get unitsPerEm]
    set asc  [$gfont get ascender]
    set dsc  [$gfont get descender]
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
                    lappend flat \
                        [expr {$x + ($pen + $fx) * $sy * $sx}] \
                        [expr {$baseline - $fy * $sy}]
                }
                if {[llength $flat] >= 6} { lappend contours $flat }
            }
            if {[llength $contours]} {
                $c fillcontours $contours -color $color -rule nonzero
            }
            $g destroy
        }
        set pen [expr {$pen + $aw}]
    }
}

# Split one CSV line into fields, honouring "quoted" fields and "" escapes.
proc ::tclutils::tusankey::_splitCsvLine {line} {
    set fields {}
    set field ""
    set inq 0
    set n [string length $line]
    for {set i 0} {$i < $n} {incr i} {
        set ch [string index $line $i]
        if {$inq} {
            if {$ch eq "\""} {
                if {[string index $line [expr {$i+1}]] eq "\""} {
                    append field "\""
                    incr i
                } else {
                    set inq 0
                }
            } else {
                append field $ch
            }
        } else {
            if {$ch eq "\""} {
                set inq 1
            } elseif {$ch eq ","} {
                lappend fields $field
                set field ""
            } else {
                append field $ch
            }
        }
    }
    lappend fields $field
    return $fields
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tusankey::parse {text} {
    set order {}            ;# node names, first-seen order
    array set seen {}
    set links {}            ;# list of {source target value}

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {[regexp -nocase {^sankey(-beta)?$} $line]} continue

        set f [_splitCsvLine $line]
        if {[llength $f] < 3} continue
        set s [string trim [lindex $f 0]]
        set t [string trim [lindex $f 1]]
        set v [string trim [lindex $f 2]]
        if {$s eq "" || $t eq "" || ![string is double -strict $v] || $v <= 0} {
            continue
        }
        foreach nm [list $s $t] {
            if {![info exists seen($nm)]} { set seen($nm) 1; lappend order $nm }
        }
        lappend links [list $s $t $v]
    }
    if {![llength $links]} { _err EMPTY "no links found in sankey diagram" }
    return [dict create type sankey nodes $order links $links]
}

# longest-path rank for each node (bounded iteration -> cycle-safe)
proc ::tclutils::tusankey::_ranks {nodes links} {
    set rank [dict create]
    foreach n $nodes { dict set rank $n 0 }
    set cnt [llength $nodes]
    for {set i 0} {$i < $cnt} {incr i} {
        set changed 0
        foreach lk $links {
            lassign $lk s t
            set want [expr {[dict get $rank $s] + 1}]
            if {[dict get $rank $t] < $want} {
                dict set rank $t $want
                set changed 1
            }
        }
        if {!$changed} break
    }
    return $rank
}

# --- draw --------------------------------------------------------------------

proc ::tclutils::tusankey::_draw {c model o gfont} {
    variable palette
    # Same scale convention as the other 2D renderers: read the real canvas size
    # and use -scale as the geometry factor gs. tupngdraw does not transform
    # coordinates, so for PNG the canvas is gs-times larger (toPng) and every
    # fixed pixel size and the text scale is multiplied by gs; SVG uses gs=1.
    # SVG and PNG therefore stay geometrically congruent.
    set W  [$c width]
    set H  [$c height]
    set gs [dict get $o -scale]
    set nodes [dict get $model nodes]
    set links [dict get $model links]

    set rank [_ranks $nodes $links]
    set maxRank 0
    foreach n $nodes { set maxRank [expr {max($maxRank, [dict get $rank $n])}] }

    # per-node value = max(inflow, outflow); colour by first-seen index
    set idx 0
    array set inSum {}; array set outSum {}; array set colorOf {}
    foreach n $nodes {
        set inSum($n) 0.0; set outSum($n) 0.0
        set colorOf($n) [lindex $palette [expr {$idx % [llength $palette]}]]
        incr idx
    }
    foreach lk $links {
        lassign $lk s t v
        set outSum($s) [expr {$outSum($s) + $v}]
        set inSum($t)  [expr {$inSum($t)  + $v}]
    }
    array set nodeVal {}
    foreach n $nodes { set nodeVal($n) [expr {max($inSum($n), $outSum($n))}] }

    # group nodes by rank (first-seen order within a rank)
    array set rankNodes {}
    for {set r 0} {$r <= $maxRank} {incr r} { set rankNodes($r) {} }
    foreach n $nodes { lappend rankNodes([dict get $rank $n]) $n }

    # geometry: margins, node width, value->pixel scale
    set padX [expr {12*$gs}]; set padY [expr {16*$gs}]
    set nodeW [expr {14*$gs}]
    set gap   [expr {8*$gs}]   ;# vertical gap between stacked nodes
    set plotW [expr {$W - 2*$padX}]
    set plotH [expr {$H - 2*$padY}]
    # the tallest rank (sum of node values + gaps) sets the scale
    set maxColVal 0.0
    for {set r 0} {$r <= $maxRank} {incr r} {
        set sum 0.0
        foreach n $rankNodes($r) { set sum [expr {$sum + $nodeVal($n)}] }
        set maxColVal [expr {max($maxColVal, $sum)}]
    }
    if {$maxColVal <= 0} { _err EMPTY "sankey has no positive flow" }
    # reserve gap space in the densest column
    set maxCount 0
    for {set r 0} {$r <= $maxRank} {incr r} {
        set maxCount [expr {max($maxCount, [llength $rankNodes($r)])}]
    }
    set usableH [expr {$plotH - ($maxCount-1)*$gap}]
    if {$usableH < 20} { set usableH 20 }
    set vscale [expr {$usableH / $maxColVal}]

    # x of each rank's left edge
    if {$maxRank > 0} {
        set colSpan [expr {($plotW - $nodeW) / double($maxRank)}]
    } else {
        set colSpan 0
    }

    # assign node boxes: {x0 y0 x1 y1}
    array set box {}
    for {set r 0} {$r <= $maxRank} {incr r} {
        set colNodes $rankNodes($r)
        # centre the column vertically
        set colH 0.0
        foreach n $colNodes { set colH [expr {$colH + $nodeVal($n)*$vscale}] }
        set colH [expr {$colH + ([llength $colNodes]-1)*$gap}]
        set y [expr {$padY + ($plotH - $colH)/2.0}]
        set x0 [expr {$padX + $r*$colSpan}]
        set x1 [expr {$x0 + $nodeW}]
        foreach n $colNodes {
            set h [expr {$nodeVal($n)*$vscale}]
            set box($n) [list $x0 $y $x1 [expr {$y+$h}]]
            set y [expr {$y + $h + $gap}]
        }
    }

    # link bands: stack outgoing at source (right edge), incoming at target
    # (left edge), in link order.
    array set outOff {}; array set inOff {}
    foreach n $nodes { set outOff($n) 0.0; set inOff($n) 0.0 }
    foreach lk $links {
        lassign $lk s t v
        set h [expr {$v*$vscale}]
        lassign $box($s) sx0 sy0 sx1 sy1
        lassign $box($t) tx0 ty0 tx1 ty1
        set ya0 [expr {$sy0 + $outOff($s)}]      ;# source band top
        set ya1 [expr {$ya0 + $h}]
        set yb0 [expr {$ty0 + $inOff($t)}]       ;# target band top
        set yb1 [expr {$yb0 + $h}]
        set outOff($s) [expr {$outOff($s) + $h}]
        set inOff($t)  [expr {$inOff($t)  + $h}]
        set xa $sx1                               ;# from source right edge
        set xb $tx0                               ;# to target left edge
        # smooth S-curve band as a filled polygon: top edge L->R, bottom R->L
        set steps 14
        set pts {}
        for {set i 0} {$i <= $steps} {incr i} {
            set u [expr {$i/double($steps)}]
            set sm [expr {$u*$u*(3-2*$u)}]        ;# smoothstep
            set x [expr {$xa + ($xb-$xa)*$u}]
            set y [expr {$ya0 + ($yb0-$ya0)*$sm}]
            lappend pts [expr {int($x)}] [expr {int($y)}]
        }
        for {set i $steps} {$i >= 0} {incr i -1} {
            set u [expr {$i/double($steps)}]
            set sm [expr {$u*$u*(3-2*$u)}]
            set x [expr {$xa + ($xb-$xa)*$u}]
            set y [expr {$ya1 + ($yb1-$ya1)*$sm}]
            lappend pts [expr {int($x)}] [expr {int($y)}]
        }
        $c polygon $pts -fill 1 -fillcolor [_lighten $colorOf($s) 0.45] -outline 0
    }

    # node boxes on top of the bands
    foreach n $nodes {
        lassign $box($n) x0 y0 x1 y1
        $c rect [expr {int($x0)}] [expr {int($y0)}] [expr {int($x1)}] [expr {int($y1)}] \
            -fill 1 -fillcolor $colorOf($n) -outline 0
    }

    # labels: inside-pointing (right of node, or left for the last rank)
    set fs $gs
    foreach n $nodes {
        lassign $box($n) x0 y0 x1 y1
        set ly [expr {int(($y0+$y1)/2.0 - 4*$fs)}]
        if {[dict get $rank $n] == $maxRank && $maxRank > 0} {
            set tw [$c textwidth $n -scale $fs]
            _drawText $c $gfont $fs [expr {int($x0 - 4*$gs - $tw)}] $ly $n "#333333"
        } else {
            _drawText $c $gfont $fs [expr {int($x1 + 4*$gs)}] $ly $n "#333333"
        }
    }
}

# --- backends ----------------------------------------------------------------

proc ::tclutils::tusankey::toSvg {model args} {
    set o [_opts {*}$args]
    package require tclutils::tusvg 0.2
    set c [::tclutils::tusvg::new \
        -width [dict get $o -width] -height [dict get $o -height] \
        -background white]
    _draw $c $model $o ""
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tusankey::toPng {model args} {
    set o [_opts {*}$args]
    package require tclutils::tupngdraw
    set sc [dict get $o -scale]
    set c [::tclutils::tupngdraw::new \
        -width  [expr {[dict get $o -width]  * $sc}] \
        -height [expr {[dict get $o -height] * $sc}] \
        -background white]
    catch {$c setantialias 1}
    set gf [_resolveFont $c [dict get $o -fontfile]]
    if {[catch {_draw $c $model $o $gf} err opt]} {
        catch {$gf destroy}
        catch {$c destroy}
        return -options $opt $err
    }
    catch {$gf destroy}
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tusankey::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tusankey::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tusankey 0.1
