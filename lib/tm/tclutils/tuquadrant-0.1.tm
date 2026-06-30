# tuquadrant-0.1.tm -- parse and render a Mermaid `quadrantChart` block to SVG or
# Description: parse and render a Mermaid `quadrantChart` block to SVG or PNG (pure-Tcl backends)
# Category: Diagrams · Mermaid
# PNG through the pure-Tcl backends (tusvg / tupngdraw), so a quadrant chart can
# be shown natively everywhere -- no browser. Like `tupie` / `tuxychart`, this is
# NOT a graph; it renders directly and is reached through the `tclutils::tuflow`
# facade (`tuflow::toPng` / `toSvg`), which dispatches `quadrantChart` here.
#
# Supported syntax (Mermaid subset):
#   quadrantChart                      -> header
#   title <text>                       -> chart title
#   x-axis <left> --> <right>          -> x-axis end labels (axis is 0..1)
#   y-axis <bottom> --> <top>          -> y-axis end labels (axis is 0..1)
#   quadrant-1 <text> ... quadrant-4   -> quadrant labels
#                                         (1=top-right, 2=top-left,
#                                          3=bottom-left, 4=bottom-right)
#   <Point Name>: [x, y]               -> a point at normalised x,y in 0..1
#                                         (trailing style hints are ignored)
#
# v1 limitations (honest): point style hints (radius:, color:, ...) are ignored
# and points use a cycling palette; the y-axis end labels are placed
# horizontally in the left margin, not rotated; coordinates are clamped to 0..1.
#
# Namespace: ::tclutils::tuquadrant   Package: tclutils::tuquadrant 0.1
# Errors:    {TCLUTILS TUQUADRANT <REASON>}   REASON in EMPTY, ARG, FONT

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils::tuquadrant {
    namespace export parse toSvg toPng writeSvg writePng
    variable palette {
        #4e79a7 #f28e2b #e15759 #76b7b2 #59a14f
        #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac
    }
    # light quadrant tints, indexed q1 q2 q3 q4
    variable qfill {#eaf2fb #fdf1e8 #ecf6ec #fcecec}
}

# --- helpers (shared shape with tupie / tuxychart) --------------------------

proc ::tclutils::tuquadrant::_unquote {s} {
    set s [string trim $s]
    set n [string length $s]
    if {$n >= 2} {
        set a [string index $s 0]
        set b [string index $s end]
        if {($a eq "\"" && $b eq "\"") || ($a eq "'" && $b eq "'")} {
            return [string range $s 1 end-1]
        }
    }
    return $s
}

proc ::tclutils::tuquadrant::_drawText {c gfont scale x y str color} {
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

proc ::tclutils::tuquadrant::_drawCentered {c gfont scale cx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($cx - $w / 2.0)}] $ty $str $color
}

proc ::tclutils::tuquadrant::_drawRight {c gfont scale rx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($rx - $w)}] $ty $str $color
}

proc ::tclutils::tuquadrant::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 420 -height 420 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        return -code error -errorcode {TCLUTILS TUQUADRANT ARG} \
            "-scale must be a positive integer"
    }
    return $o
}

proc ::tclutils::tuquadrant::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} {
        return -code error -errorcode {TCLUTILS TUQUADRANT FONT} \
            "font file not found: $fontfile"
    }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""
    catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

proc ::tclutils::tuquadrant::_clamp01 {v} {
    if {![string is double -strict $v]} { return 0.0 }
    if {$v < 0} { return 0.0 }
    if {$v > 1} { return 1.0 }
    return $v
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tuquadrant::parse {text} {
    set title ""
    set xleft "" ; set xright ""
    set ybottom "" ; set ytop ""
    array set quad {1 {} 2 {} 3 {} 4 {}}
    set points {}
    set sawHeader 0
    set sawContent 0

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {!$sawHeader && [regexp -nocase {^quadrantChart\M} $line]} {
            set sawHeader 1
            continue
        }
        if {[regexp -nocase {^title\s+(.+)$} $line -> t]} {
            set title [_unquote $t]; set sawContent 1; continue
        }
        if {[regexp -nocase {^x-axis\s+(.*)$} $line -> rest]} {
            if {[regexp {^(.*?)\s*-->\s*(.*)$} $rest -> a b]} {
                set xleft [_unquote [string trim $a]]
                set xright [_unquote [string trim $b]]
            } else {
                set xleft [_unquote [string trim $rest]]
            }
            set sawContent 1; continue
        }
        if {[regexp -nocase {^y-axis\s+(.*)$} $line -> rest]} {
            if {[regexp {^(.*?)\s*-->\s*(.*)$} $rest -> a b]} {
                set ybottom [_unquote [string trim $a]]
                set ytop [_unquote [string trim $b]]
            } else {
                set ybottom [_unquote [string trim $rest]]
            }
            set sawContent 1; continue
        }
        if {[regexp -nocase {^quadrant-([1-4])\s+(.+)$} $line -> q txt]} {
            set quad($q) [_unquote [string trim $txt]]
            set sawContent 1; continue
        }
        # point:  Name : [x, y]   (ignore any trailing style hints)
        if {[regexp {^(.+?)\s*:\s*\[\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*\]} $line -> nm x y]} {
            lappend points [list [_unquote [string trim $nm]] [_clamp01 $x] [_clamp01 $y]]
            set sawContent 1; continue
        }
    }

    if {!$sawContent} {
        return -code error -errorcode {TCLUTILS TUQUADRANT EMPTY} \
            "no content found in quadrantChart source"
    }
    return [dict create title $title \
        xleft $xleft xright $xright ybottom $ybottom ytop $ytop \
        q1 $quad(1) q2 $quad(2) q3 $quad(3) q4 $quad(4) \
        points $points]
}

# --- draw (shared across backends) -------------------------------------------

proc ::tclutils::tuquadrant::_draw {c model o gfont} {
    variable palette
    variable qfill
    set W  [$c width]
    set H  [$c height]
    set fs [dict get $o -scale]
    set np [llength $palette]

    set title [dict get $model title]

    set pad     [expr {12 * $fs}]
    set titleH  [expr {$title ne "" ? 18 * $fs : 0}]
    set xLabH   [expr {16 * $fs}]

    # dynamic left margin to fit the (horizontal) y-axis end labels
    set leftW 0
    foreach s [list [dict get $model ytop] [dict get $model ybottom]] {
        if {$s ne ""} { set leftW [expr {max($leftW, [$c textwidth $s -scale $fs])}] }
    }
    if {$leftW > 0} { set leftW [expr {min($leftW + 6 * $fs, int($W * 0.30))}] }

    set px0 [expr {$pad + $leftW}]
    set px1 [expr {$W - $pad}]
    set py0 [expr {$pad + $titleH}]
    set py1 [expr {$H - $pad - $xLabH}]
    if {$px1 - $px0 < 20} { set px1 [expr {$px0 + 20}] }
    if {$py1 - $py0 < 20} { set py1 [expr {$py0 + 20}] }

    set mx [expr {($px0 + $px1) / 2.0}]
    set my [expr {($py0 + $py1) / 2.0}]

    if {$title ne ""} {
        _drawCentered $c $gfont $fs [expr {$W / 2.0}] $pad $title black
    }

    # quadrant tints: q1 TR, q2 TL, q3 BL, q4 BR
    $c rect $mx  $py0 $px1 $my  -fill 1 -fillcolor [lindex $qfill 0] -outline 0
    $c rect $px0 $py0 $mx  $my  -fill 1 -fillcolor [lindex $qfill 1] -outline 0
    $c rect $px0 $my  $mx  $py1 -fill 1 -fillcolor [lindex $qfill 2] -outline 0
    $c rect $mx  $my  $px1 $py1 -fill 1 -fillcolor [lindex $qfill 3] -outline 0

    # frame + mid lines
    $c rect $px0 $py0 $px1 $py1 -fill 0 -outline 1 -color #999999
    $c line $mx $py0 $mx $py1 -color #999999 -width $fs
    $c line $px0 $my $px1 $my -color #999999 -width $fs

    # quadrant labels, centred in each quadrant
    set qcx1 [expr {($mx + $px1) / 2.0}]; set qcx0 [expr {($px0 + $mx) / 2.0}]
    set qcyT [expr {($py0 + $my) / 2.0 - 4 * $fs}]
    set qcyB [expr {($my + $py1) / 2.0 - 4 * $fs}]
    if {[dict get $model q1] ne ""} { _drawCentered $c $gfont $fs $qcx1 $qcyT [dict get $model q1] #555555 }
    if {[dict get $model q2] ne ""} { _drawCentered $c $gfont $fs $qcx0 $qcyT [dict get $model q2] #555555 }
    if {[dict get $model q3] ne ""} { _drawCentered $c $gfont $fs $qcx0 $qcyB [dict get $model q3] #555555 }
    if {[dict get $model q4] ne ""} { _drawCentered $c $gfont $fs $qcx1 $qcyB [dict get $model q4] #555555 }

    # points: normalised (0,0)=bottom-left -> (1,1)=top-right
    set pr [expr {4 * $fs}]
    set i 0
    foreach p [dict get $model points] {
        lassign $p nm x y
        set cx [expr {$px0 + $x * ($px1 - $px0)}]
        set cy [expr {$py1 - $y * ($py1 - $py0)}]
        set col [lindex $palette [expr {$i % $np}]]
        $c circle $cx $cy $pr -fill 1 -fillcolor $col -outline 0
        _drawText $c $gfont $fs [expr {int($cx + $pr + 2 * $fs)}] [expr {int($cy - 4 * $fs)}] $nm #333333
        incr i
    }

    # axis end labels
    set ly [expr {$py1 + 2 * $fs}]
    if {[dict get $model xleft]  ne ""} { _drawText  $c $gfont $fs $px0 $ly [dict get $model xleft]  #333333 }
    if {[dict get $model xright] ne ""} { _drawRight $c $gfont $fs $px1 $ly [dict get $model xright] #333333 }
    set rx [expr {$px0 - 4 * $fs}]
    if {[dict get $model ytop]    ne ""} { _drawRight $c $gfont $fs $rx [expr {int($py0 + ($py1 - $py0) * 0.25)}] [dict get $model ytop]    #333333 }
    if {[dict get $model ybottom] ne ""} { _drawRight $c $gfont $fs $rx [expr {int($py0 + ($py1 - $py0) * 0.75)}] [dict get $model ybottom] #333333 }
}

# --- public render -----------------------------------------------------------

proc ::tclutils::tuquadrant::toSvg {model args} {
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

proc ::tclutils::tuquadrant::toPng {model args} {
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

proc ::tclutils::tuquadrant::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tuquadrant::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tuquadrant 0.1
