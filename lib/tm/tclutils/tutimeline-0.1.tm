# tutimeline-0.1.tm -- parse and render a Mermaid `timeline` block to SVG or PNG
# Description: parse and render a Mermaid `timeline` block to SVG or PNG (pure-Tcl backends)
# Category: Diagrams · Mermaid
# through the pure-Tcl backends (tusvg / tupngdraw), so a timeline can be shown
# natively everywhere -- no browser. Like `tupie` / `tuxychart`, this is NOT a
# graph; it renders directly and is reached through the `tclutils::tuflow`
# facade (`tuflow::toPng` / `toSvg`), which dispatches `timeline` here.
#
# Supported syntax (Mermaid subset):
#   timeline                           -> header
#   title <text>                       -> chart title
#   section <name>                     -> starts a section; following periods
#                                         belong to it
#   <time> : <event> : <event> ...     -> a time period with one or more events
#   : <event>                          -> continuation: more events for the
#                                         previous period
#
# Rendered horizontally: a time axis with the period labels below it and each
# period's events stacked as boxes above it; sections are coloured bands across
# the top.
#
# v1 limitations (honest): horizontal layout only; long event text or many
# periods may crowd or clip (no wrapping/rotation); a section is a contiguous
# run of periods (as Mermaid emits them).
#
# Namespace: ::tclutils::tutimeline   Package: tclutils::tutimeline 0.1
# Errors:    {TCLUTILS TUTIMELINE <REASON>}   REASON in EMPTY, ARG, FONT

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils::tutimeline {
    namespace export parse toSvg toPng writeSvg writePng
    variable palette {
        #4e79a7 #f28e2b #e15759 #76b7b2 #59a14f
        #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac
    }
    variable bandfill {#eaf2fb #fdf1e8 #ecf6ec #fcecec #eef7f6 #fbf6e6}
}

# --- helpers (shared shape with tupie / tuxychart / tujourney) --------------

proc ::tclutils::tutimeline::_unquote {s} {
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

proc ::tclutils::tutimeline::_drawText {c gfont scale x y str color} {
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

proc ::tclutils::tutimeline::_drawCentered {c gfont scale cx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($cx - $w / 2.0)}] $ty $str $color
}

proc ::tclutils::tutimeline::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 640 -height 380 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        return -code error -errorcode {TCLUTILS TUTIMELINE ARG} \
            "-scale must be a positive integer"
    }
    return $o
}

proc ::tclutils::tutimeline::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} {
        return -code error -errorcode {TCLUTILS TUTIMELINE FONT} \
            "font file not found: $fontfile"
    }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""
    catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tutimeline::parse {text} {
    set title ""
    set periods {}          ;# list of {time {events} section}
    set sections {}         ;# ordered unique section names
    set cur ""
    set sawHeader 0

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {!$sawHeader && [regexp -nocase {^timeline\M} $line]} { set sawHeader 1; continue }
        if {[regexp -nocase {^title\s+(.+)$} $line -> t]} { set title [_unquote $t]; continue }
        if {[regexp -nocase {^section\s+(.+)$} $line -> s]} {
            set cur [_unquote [string trim $s]]
            if {$cur ni $sections} { lappend sections $cur }
            continue
        }

        set parts [split $line :]
        if {[string index $line 0] eq ":"} {
            # continuation: events for the previous period
            if {![llength $periods]} continue
            set last [lindex $periods end]
            set evs [lindex $last 1]
            foreach p [lrange $parts 1 end] {
                set p [_unquote [string trim $p]]
                if {$p ne ""} { lappend evs $p }
            }
            lset periods end 1 $evs
            continue
        }

        set time [_unquote [string trim [lindex $parts 0]]]
        if {$time eq ""} continue
        set evs {}
        foreach p [lrange $parts 1 end] {
            set p [_unquote [string trim $p]]
            if {$p ne ""} { lappend evs $p }
        }
        lappend periods [list $time $evs $cur]
    }

    if {![llength $periods]} {
        return -code error -errorcode {TCLUTILS TUTIMELINE EMPTY} \
            "no time periods found in timeline source"
    }
    return [dict create title $title periods $periods sections $sections]
}

# --- draw (shared across backends) -------------------------------------------

proc ::tclutils::tutimeline::_draw {c model o gfont} {
    variable palette
    variable bandfill
    set W  [$c width]
    set H  [$c height]
    set fs [dict get $o -scale]
    set np [llength $palette]
    set nb [llength $bandfill]

    set title    [dict get $model title]
    set periods  [dict get $model periods]
    set sections [dict get $model sections]
    set npr [llength $periods]
    if {$npr < 1} { set npr 1 }

    set pad      [expr {12 * $fs}]
    set titleH   [expr {$title ne "" ? 18 * $fs : 0}]
    set bandH    [expr {16 * $fs}]
    set periodH  [expr {14 * $fs}]

    set px0 $pad
    set px1 [expr {$W - $pad}]
    if {$px1 - $px0 < 20} { set px1 [expr {$px0 + 20}] }
    set axisY [expr {$H - $pad - $periodH}]
    set evTop [expr {$pad + $titleH + $bandH + 4 * $fs}]

    set slotW [expr {($px1 - $px0) / double($npr)}]
    set boxW [expr {$slotW * 0.85}]
    set boxH [expr {16 * $fs}]
    set gap  [expr {5 * $fs}]

    if {$title ne ""} {
        _drawCentered $c $gfont $fs [expr {$W / 2.0}] $pad $title black
    }

    # section bands: contiguous runs across the top
    set bandY0 [expr {$pad + $titleH}]
    set bandY1 [expr {$bandY0 + $bandH}]
    set i 0; set si 0
    while {$i < [llength $periods]} {
        set sec [lindex [lindex $periods $i] 2]
        set j $i
        while {$j < [llength $periods] && [lindex [lindex $periods $j] 2] eq $sec} { incr j }
        set bx0 [expr {$px0 + $i * $slotW}]
        set bx1 [expr {$px0 + $j * $slotW}]
        $c rect $bx0 $bandY0 $bx1 $bandY1 \
            -fill 1 -fillcolor [lindex $bandfill [expr {$si % $nb}]] -outline 0
        if {$sec ne ""} {
            _drawCentered $c $gfont $fs [expr {($bx0 + $bx1) / 2.0}] \
                [expr {int($bandY0 + 4 * $fs)}] $sec #555555
        }
        set i $j; incr si
    }

    # axis
    $c line $px0 $axisY $px1 $axisY -color #333333 -width [expr {2 * $fs}]

    for {set i 0} {$i < [llength $periods]} {incr i} {
        lassign [lindex $periods $i] time evs sec
        set cx [expr {$px0 + ($i + 0.5) * $slotW}]
        set cidx [expr {$sec ne "" ? [lsearch -exact $sections $sec] : $i}]
        set stroke [lindex $palette [expr {$cidx % $np}]]
        set fill   [lindex $bandfill [expr {$cidx % $nb}]]

        # axis marker + stub
        $c circle $cx $axisY [expr {4 * $fs}] -fill 1 -fillcolor $stroke -outline 0
        $c line $cx $axisY $cx [expr {$axisY - $gap}] -color $stroke -width $fs

        # period label below the axis
        _drawCentered $c $gfont $fs $cx [expr {int($axisY + 3 * $fs)}] $time #333333

        # event boxes stacked above the axis
        set k 0
        foreach ev $evs {
            set bBot [expr {$axisY - $gap - $k * ($boxH + $gap)}]
            set bTop [expr {$bBot - $boxH}]
            if {$bTop < $evTop} break    ;# out of room (honest)
            $c rect [expr {$cx - $boxW / 2.0}] $bTop [expr {$cx + $boxW / 2.0}] $bBot \
                -fill 1 -fillcolor $fill -outline 1 -color $stroke -rx [expr {3 * $fs}]
            _drawCentered $c $gfont $fs $cx [expr {int($bTop + 4 * $fs)}] $ev #333333
            incr k
        }
    }
}

# --- public render -----------------------------------------------------------

proc ::tclutils::tutimeline::toSvg {model args} {
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

proc ::tclutils::tutimeline::toPng {model args} {
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

proc ::tclutils::tutimeline::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tutimeline::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tutimeline 0.1
