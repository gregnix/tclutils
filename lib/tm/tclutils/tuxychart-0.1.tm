# tuxychart-0.1.tm -- parse and render a Mermaid `xychart-beta` block to SVG or
# Description: parse and render a Mermaid `xychart-beta` block to SVG or PNG (pure-Tcl backends)
# Category: Diagrams · Mermaid
# PNG through the pure-Tcl backends (tusvg / tupngdraw), so an xychart can be
# shown natively everywhere -- no browser. Like `tupie`, this is NOT a graph; it
# renders directly and is reached through the `tclutils::tuflow` facade
# (`tuflow::toPng` / `toSvg`), which dispatches `xychart-beta` here.
#
# Supported syntax (Mermaid subset):
#   xychart-beta                       -> header (a trailing `horizontal` is
#                                         accepted but v1 always draws vertical)
#   title "..."                        -> chart title
#   x-axis "title"? [a, b, c, ...]     -> categorical axis (labels)
#   x-axis "title"? min --> max        -> numeric axis (labels synthesised)
#   y-axis "title"? (min --> max)?     -> axis title and/or explicit range;
#                                         without a range the scale is auto
#   bar  [v1, v2, ...]                 -> a bar series   (multiple allowed)
#   line [v1, v2, ...]                 -> a line series  (multiple allowed)
#
# v1 limitations (honest): only the vertical orientation is drawn (a trailing
# `horizontal` is ignored); the y-axis title is drawn horizontally in a band
# above the axis (not rotated); series are coloured from a fixed palette; bar
# groups share each
# category slot side by side.
#
# Namespace: ::tclutils::tuxychart   Package: tclutils::tuxychart 0.1
# Errors:    {TCLUTILS TUXYCHART <REASON>}   REASON in EMPTY, VALUE, ARG

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils::tuxychart {
    namespace export parse toSvg toPng writeSvg writePng
    variable palette {
        #4e79a7 #f28e2b #e15759 #76b7b2 #59a14f
        #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac
    }
}

# --- helpers (shared shape with tupie) --------------------------------------

proc ::tclutils::tuxychart::_unquote {s} {
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

# Draw one line of text: bitmap by default, or a real outline font (gfont)
# squeezed into the 6x8 metric box, so SVG and raster layouts stay congruent.
proc ::tclutils::tuxychart::_drawText {c gfont scale x y str color} {
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

proc ::tclutils::tuxychart::_drawCentered {c gfont scale cx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($cx - $w / 2.0)}] $ty $str $color
}

proc ::tclutils::tuxychart::_drawRight {c gfont scale rx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($rx - $w)}] $ty $str $color
}

proc ::tclutils::tuxychart::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 520 -height 340 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        return -code error -errorcode {TCLUTILS TUXYCHART ARG} \
            "-scale must be a positive integer"
    }
    return $o
}

proc ::tclutils::tuxychart::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} {
        return -code error -errorcode {TCLUTILS TUXYCHART FONT} \
            "font file not found: $fontfile"
    }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""
    catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

# Round a positive value up to a "nice" 1/2/5 * 10^k number (axis ceiling).
proc ::tclutils::tuxychart::_niceCeil {v} {
    if {$v <= 0} { return 1.0 }
    set expo [expr {floor(log10($v))}]
    set base [expr {pow(10, $expo)}]
    set f [expr {$v / $base}]
    set nf [expr {$f <= 1 ? 1 : ($f <= 2 ? 2 : ($f <= 5 ? 5 : 10))}]
    return [expr {$nf * $base}]
}

# Format a tick value compactly (integer if whole, else trimmed decimal).
proc ::tclutils::tuxychart::_fmt {v} {
    if {abs($v - round($v)) < 1e-9} { return [expr {wide(round($v))}] }
    return [format %.2f $v]
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tuxychart::parse {text} {
    set title ""
    set orient vertical
    set xtitle ""
    set cats {}
    set xnumeric 0
    set xmin 0.0
    set xmax 0.0
    set ytitle ""
    set yauto 1
    set ymin 0.0
    set ymax 0.0
    set series {}
    set sawHeader 0

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {!$sawHeader && [regexp -nocase {^xychart-beta\M(.*)$} $line -> rest]} {
            set sawHeader 1
            if {[regexp -nocase {\mhorizontal\M} $rest]} { set orient horizontal }
            continue
        }
        if {[regexp -nocase {^title\s+(.+)$} $line -> t]} {
            set title [_unquote $t]
            continue
        }
        if {[regexp -nocase {^x-axis\s+(.*)$} $line -> rest]} {
            set rest [string trim $rest]
            if {[regexp {^\"([^\"]*)\"\s*(.*)$} $rest -> qt more]} {
                set xtitle $qt
                set rest [string trim $more]
            }
            if {[regexp {\[(.*)\]} $rest -> inside]} {
                set cats {}
                foreach item [split $inside ,] {
                    lappend cats [_unquote [string trim $item]]
                }
            } elseif {[regexp {([-0-9.]+)\s*-->\s*([-0-9.]+)} $rest -> a b]} {
                set xnumeric 1
                set xmin $a
                set xmax $b
            } elseif {$xtitle eq "" && $rest ne ""} {
                set xtitle [_unquote $rest]
            }
            continue
        }
        if {[regexp -nocase {^y-axis\s+(.*)$} $line -> rest]} {
            set rest [string trim $rest]
            if {[regexp {^\"([^\"]*)\"\s*(.*)$} $rest -> qt more]} {
                set ytitle $qt
                set rest [string trim $more]
            } elseif {![regexp -- {-->} $rest]} {
                set ytitle [_unquote $rest]
                set rest ""
            }
            if {[regexp {([-0-9.]+)\s*-->\s*([-0-9.]+)} $rest -> a b]} {
                set yauto 0
                set ymin $a
                set ymax $b
            }
            continue
        }
        if {[regexp -nocase {^(bar|line)\s*\[(.*)\]} $line -> kind inside]} {
            set vals {}
            foreach item [split $inside ,] {
                set v [string trim $item]
                if {$v eq ""} continue
                if {![string is double -strict $v]} {
                    return -code error -errorcode {TCLUTILS TUXYCHART VALUE} \
                        "non-numeric value in $kind series: $v"
                }
                lappend vals $v
            }
            lappend series [dict create type [string tolower $kind] values $vals]
            continue
        }
    }

    if {![llength $series]} {
        return -code error -errorcode {TCLUTILS TUXYCHART EMPTY} \
            "no bar or line series found in xychart source"
    }
    return [dict create \
        title $title orientation $orient \
        xtitle $xtitle categories $cats xnumeric $xnumeric xmin $xmin xmax $xmax \
        ytitle $ytitle yauto $yauto ymin $ymin ymax $ymax \
        series $series]
}

# --- draw (shared across backends) -------------------------------------------

proc ::tclutils::tuxychart::_draw {c model o gfont} {
    variable palette
    set W  [$c width]
    set H  [$c height]
    set fs [dict get $o -scale]
    set np [llength $palette]

    set title  [dict get $model title]
    set series [dict get $model series]
    set cats   [dict get $model categories]

    # number of categories = explicit labels, else the longest series
    set n [llength $cats]
    foreach s $series { set n [expr {max($n, [llength [dict get $s values]])}] }
    if {$n < 1} { set n 1 }
    if {![llength $cats]} {
        for {set i 0} {$i < $n} {incr i} {
            if {[dict get $model xnumeric]} {
                set xmin [dict get $model xmin]; set xmax [dict get $model xmax]
                set v [expr {$n <= 1 ? $xmin : $xmin + ($xmax - $xmin) * $i / double($n - 1)}]
                lappend cats [_fmt $v]
            } else {
                lappend cats [expr {$i + 1}]
            }
        }
    }

    # y range
    if {[dict get $model yauto]} {
        set dmin 0.0; set dmax 0.0; set any 0
        foreach s $series {
            foreach v [dict get $s values] {
                if {!$any} { set dmin $v; set dmax $v; set any 1 }
                set dmin [expr {min($dmin, $v)}]
                set dmax [expr {max($dmax, $v)}]
            }
        }
        set yMin [expr {$dmin < 0 ? -[_niceCeil [expr {abs($dmin)}]] : 0.0}]
        set yMax [expr {$dmax > 0 ? [_niceCeil $dmax] : 0.0}]
        if {$yMax <= $yMin} { set yMax [expr {$yMin + 1}] }
    } else {
        set yMin [dict get $model ymin]
        set yMax [dict get $model ymax]
        if {$yMax <= $yMin} { set yMax [expr {$yMin + 1}] }
    }

    # layout
    set pad     [expr {12 * $fs}]
    set titleH  [expr {$title ne "" ? 18 * $fs : 0}]
    # y-axis title is drawn horizontally in a band ABOVE the plot (next to the
    # top of the y-axis) so it never collides with the topmost tick label.
    set yTitleW 0
    set yTitleH [expr {[dict get $model ytitle] ne "" ? 14 * $fs : 0}]
    set yLabW   [expr {32 * $fs}]
    set xLabH   [expr {14 * $fs}]
    set xTitleH [expr {[dict get $model xtitle] ne "" ? 14 * $fs : 0}]

    set px0 [expr {$pad + $yTitleW + $yLabW}]
    set px1 [expr {$W - $pad}]
    set py0 [expr {$pad + $titleH + $yTitleH}]
    set py1 [expr {$H - $pad - $xLabH - $xTitleH}]
    if {$px1 - $px0 < 10} { set px1 [expr {$px0 + 10}] }
    if {$py1 - $py0 < 10} { set py1 [expr {$py0 + 10}] }

    set yspan [expr {double($yMax - $yMin)}]
    set toY {v {
        upvar 1 py0 py0 py1 py1 yMin yMin yspan yspan
        expr {$py1 - ($v - $yMin) / $yspan * ($py1 - $py0)}
    }}

    if {$title ne ""} {
        _drawCentered $c $gfont $fs [expr {$W / 2.0}] $pad $title black
    }

    # y grid + ticks (5 lines) and labels
    set ticks 5
    for {set k 0} {$k < $ticks} {incr k} {
        set v  [expr {$yMin + $yspan * $k / double($ticks - 1)}]
        set yy [apply $toY $v]
        $c line $px0 $yy $px1 $yy -color #dddddd -width $fs
        _drawRight $c $gfont $fs [expr {$px0 - 4 * $fs}] [expr {int($yy - 4 * $fs)}] [_fmt $v] #555555
    }

    # axes
    $c setlinewidth [expr {$fs}]
    $c line $px0 $py0 $px0 $py1 -color #333333 -width $fs
    $c line $px0 $py1 $px1 $py1 -color #333333 -width $fs

    set slotW [expr {($px1 - $px0) / double($n)}]

    # x labels (centred under each slot)
    for {set i 0} {$i < $n} {incr i} {
        set cx [expr {$px0 + ($i + 0.5) * $slotW}]
        _drawCentered $c $gfont $fs $cx [expr {$py1 + 2 * $fs}] [lindex $cats $i] #555555
    }

    # baseline value for bars (zero if in range, else yMin)
    set zeroV [expr {($yMin <= 0 && $yMax >= 0) ? 0.0 : $yMin}]
    set baseY [apply $toY $zeroV]

    # count bar series for side-by-side grouping
    set nbar 0
    foreach s $series { if {[dict get $s type] eq "bar"} { incr nbar } }
    set groupW [expr {$slotW * 0.7}]
    set barW   [expr {$nbar > 0 ? $groupW / $nbar : $groupW}]

    set ci 0
    set bi 0
    foreach s $series {
        set col [lindex $palette [expr {$ci % $np}]]
        set vals [dict get $s values]
        if {[dict get $s type] eq "bar"} {
            for {set i 0} {$i < [llength $vals]} {incr i} {
                set v [lindex $vals $i]
                set cx [expr {$px0 + ($i + 0.5) * $slotW}]
                set x0 [expr {$cx - $groupW / 2.0 + $bi * $barW}]
                set x1 [expr {$x0 + $barW * 0.9}]
                set yv [apply $toY $v]
                $c rect $x0 [expr {min($yv, $baseY)}] $x1 [expr {max($yv, $baseY)}] \
                    -fill 1 -fillcolor $col -outline 0
            }
            incr bi
        } else {
            # line series: connected segments + small square markers
            set prevx ""; set prevy ""
            for {set i 0} {$i < [llength $vals]} {incr i} {
                set v [lindex $vals $i]
                set cx [expr {$px0 + ($i + 0.5) * $slotW}]
                set yv [apply $toY $v]
                if {$prevx ne ""} {
                    $c line $prevx $prevy $cx $yv -color $col -width [expr {2 * $fs}]
                }
                set prevx $cx; set prevy $yv
            }
            set m [expr {2 * $fs}]
            for {set i 0} {$i < [llength $vals]} {incr i} {
                set cx [expr {$px0 + ($i + 0.5) * $slotW}]
                set yv [apply $toY [lindex $vals $i]]
                $c rect [expr {$cx - $m}] [expr {$yv - $m}] [expr {$cx + $m}] [expr {$yv + $m}] \
                    -fill 1 -fillcolor $col -outline 0
            }
        }
        incr ci
    }

    # axis titles
    if {[dict get $model xtitle] ne ""} {
        _drawCentered $c $gfont $fs [expr {($px0 + $px1) / 2.0}] \
            [expr {$py1 + $xLabH}] [dict get $model xtitle] black
    }
    if {[dict get $model ytitle] ne ""} {
        _drawText $c $gfont $fs $px0 [expr {$pad + $titleH}] [dict get $model ytitle] #555555
    }

    # legend (only when more than one series)
    if {[llength $series] > 1} {
        set lx [expr {$px0 + 4 * $fs}]
        set ly [expr {$py0 + 2 * $fs}]
        set sw [expr {9 * $fs}]
        set ci 0
        foreach s $series {
            set col [lindex $palette [expr {$ci % $np}]]
            $c rect $lx $ly [expr {$lx + $sw}] [expr {$ly + $sw}] \
                -fill 1 -fillcolor $col -outline 0
            set lbl "[dict get $s type] [expr {$ci + 1}]"
            _drawText $c $gfont $fs [expr {$lx + $sw + 4 * $fs}] $ly $lbl #333333
            set ly [expr {$ly + 13 * $fs}]
            incr ci
        }
    }
}

# --- public render -----------------------------------------------------------

proc ::tclutils::tuxychart::toSvg {model args} {
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

proc ::tclutils::tuxychart::toPng {model args} {
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

proc ::tclutils::tuxychart::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tuxychart::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tuxychart 0.1
