# tugantt-0.1.tm -- parse and render a Mermaid `gantt` block to SVG or PNG. A
# Description: parse and render a Mermaid `gantt` block to SVG or PNG.
# Category: Diagrams · Mermaid
# self-contained 2D renderer in the tuflow family (like tupie / tusankey): own
# parser, draws onto the shared abstract canvas (tusvg / tupngdraw), so SVG and
# PNG output stay congruent.
#
# Supported syntax (Mermaid subset):
#   gantt
#     title <text>                  optional chart title
#     dateFormat <fmt>              input date format (default YYYY-MM-DD; the
#                                   usual tokens YYYY/MM/DD/HH/mm/ss map to clock
#                                   format, and "X" means a Unix timestamp)
#     axisFormat <fmt>              optional axis label format (same tokens)
#     section <name>                start a labelled group of tasks
#     <title> : [tags,] [id,] <start>, <end-or-duration>
#
#   tags (optional, first): active | done | crit | milestone
#   start: an explicit date, "after <id> [<id> ...]", or omitted (the task then
#          starts at the end of the preceding task)
#   end:   an explicit date, or a duration like 5d / 2w / 8h / 30m
#   a milestone is drawn as a diamond at start + duration/2 (no bar)
#
# Not in v1: excludes / weekend exclusion, until, vert markers, compact display,
# custom tick intervals. Comments start with %%.
#
# Namespace: ::tclutils::tugantt   Package: tclutils::tugantt 0.1
# Errors:    {TCLUTILS TUGANTT <REASON>}   REASON in EMPTY | ARG | DATE | FONT

package require Tcl 8.6 9
package require tclutils::common 0.1

namespace eval ::tclutils::tugantt {
    namespace export parse toSvg toPng writeSvg writePng
    # task fill by state: normal, active, done, crit (plus milestone marker)
    variable colors {
        normal #4e79a7  active #6fa8dc  done #9aa0a6  crit #e15759
        milestone #f1c232  grid #dddddd  sectionA #f3f4f6  sectionB #e8eaed
        text #333333  bar_outline #2f3a45
    }
}

proc ::tclutils::tugantt::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUGANTT $reason] $msg
}

# --- shared 2D-renderer scaffold ---------------------------------------------

proc ::tclutils::tugantt::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 800 -height 400 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        _err ARG "-scale must be a positive integer"
    }
    return $o
}

proc ::tclutils::tugantt::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} { _err FONT "font file not found: $fontfile" }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""
    catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

proc ::tclutils::tugantt::_drawText {c gfont scale x y str color} {
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
                    lappend flat [expr {$x + ($pen + $fx) * $sy * $sx}] \
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

proc ::tclutils::tugantt::_drawRight {c gfont scale rx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($rx - $w)}] $ty $str $color
}

# --- date / duration helpers -------------------------------------------------

# Map a Mermaid dateFormat to a Tcl clock format string. Longest tokens first.
proc ::tclutils::tugantt::_clockFmt {fmt} {
    set map {YYYY %Y YY %y MM %m DD %d HH %H mm %M ss %S}
    # protect against partial overlaps by replacing longest tokens first
    foreach {tok rep} $map {
        set fmt [string map [list $tok \x00$rep\x00] $fmt]
    }
    return [string map {\x00 {}} $fmt]
}

# Parse an instant in the given dateFormat to epoch seconds.
proc ::tclutils::tugantt::_parseInstant {tok fmt} {
    set tok [string trim $tok]
    if {$fmt eq "X"} {
        if {![string is double -strict $tok]} { _err DATE "bad timestamp: $tok" }
        return [expr {double($tok)}]
    }
    set cf [_clockFmt $fmt]
    if {[catch {clock scan $tok -format $cf -gmt 1} secs]} {
        _err DATE "cannot parse date \"$tok\" with format \"$fmt\""
    }
    return [expr {double($secs)}]
}

# Duration token (5d / 2w / 8h / 30m / 1.5d) -> seconds. Unknown unit -> 0.
proc ::tclutils::tugantt::_durationSecs {tok} {
    if {![regexp {^([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]+)$} [string trim $tok] -> n u]} {
        return 0.0
    }
    switch -- $u {
        s       { set f 1.0 }
        m - min { set f 60.0 }
        h       { set f 3600.0 }
        d       { set f 86400.0 }
        w       { set f 604800.0 }
        default { set f 0.0 }
    }
    return [expr {$n * $f}]
}

proc ::tclutils::tugantt::_isDuration {tok} {
    return [regexp {^[0-9]+(?:\.[0-9]+)?\s*[a-zA-Z]+$} [string trim $tok]]
}

# An id looks like an identifier and is not a tag, after/until ref or duration.
proc ::tclutils::tugantt::_isId {tok} {
    set tok [string trim $tok]
    if {[_isDuration $tok]} { return 0 }
    if {[string match -nocase "after *" $tok]} { return 0 }
    if {[string match -nocase "until *" $tok]} { return 0 }
    return [regexp {^[A-Za-z_][A-Za-z0-9_]*$} $tok]
}

# Split the metadata after ':' into {tags id startTok endTok}. Any of id/start
# may be empty. startTok keeps an "after ..." phrase verbatim.
proc ::tclutils::tugantt::_splitMeta {meta} {
    set items {}
    foreach it [split $meta ,] { lappend items [string trim $it] }
    set items [lmap x $items {set x}]
    set tags {}
    while {[llength $items] && [string tolower [lindex $items 0]] in {active done crit milestone}} {
        lappend tags [string tolower [lindex $items 0]]
        set items [lrange $items 1 end]
    }
    set id ""
    # an id is only the leading token when more items follow (so a lone date or
    # duration is not mistaken for an id)
    if {[llength $items] >= 2 && [_isId [lindex $items 0]]} {
        set id [lindex $items 0]
        set items [lrange $items 1 end]
    }
    set startTok ""; set endTok ""
    if {[llength $items] >= 2} {
        set startTok [lindex $items 0]
        set endTok   [lindex $items 1]
    } elseif {[llength $items] == 1} {
        set endTok [lindex $items 0]
    }
    return [list $tags $id $startTok $endTok]
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tugantt::parse {text} {
    set title ""
    set dateFormat "YYYY-MM-DD"
    set axisFormat ""
    set sections {}              ;# list of {name {taskRef ...}}
    set tasks {}                 ;# list of task dicts (definition order)
    set curSection ""
    set haveSection 0

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {[regexp -nocase {^gantt\M} $line]} continue

        if {[regexp -nocase {^title\s+(.*)$} $line -> t]} { set title [string trim $t]; continue }
        if {[regexp -nocase {^dateFormat\s+(.*)$} $line -> f]} { set dateFormat [string trim $f]; continue }
        if {[regexp -nocase {^axisFormat\s+(.*)$} $line -> f]} { set axisFormat [string trim $f]; continue }
        if {[regexp -nocase {^(excludes|todayMarker|tickInterval|weekday|vert)\M} $line]} continue
        if {[regexp -nocase {^section\s+(.*)$} $line -> s]} {
            set curSection [string trim $s]
            set haveSection 1
            continue
        }
        # task line: "<title> : <meta>"
        set colon [string first ":" $line]
        if {$colon < 0} continue
        set ttl  [string trim [string range $line 0 [expr {$colon-1}]]]
        set meta [string range $line [expr {$colon+1}] end]
        lassign [_splitMeta $meta] tags id startTok endTok
        lappend tasks [dict create \
            title $ttl section $curSection tags $tags id $id \
            startTok $startTok endTok $endTok]
    }
    if {![llength $tasks]} { _err EMPTY "no tasks found in gantt diagram" }
    return [dict create type gantt title $title \
        dateFormat $dateFormat axisFormat $axisFormat tasks $tasks \
        haveSection $haveSection]
}

# Resolve each task to absolute start/end seconds. Returns a flat list of
# resolved dicts {title section tags milestone start end}.
proc ::tclutils::tugantt::_resolve {model} {
    set fmt [dict get $model dateFormat]
    set tasks [dict get $model tasks]
    set byId [dict create]       ;# id -> {start end}
    set out {}
    set prevEnd ""
    foreach t $tasks {
        set tags [dict get $t tags]
        set milestone [expr {"milestone" in $tags}]
        set startTok [dict get $t startTok]
        set endTok   [dict get $t endTok]

        # --- start ---
        if {$startTok eq ""} {
            set start [expr {$prevEnd eq "" ? 0.0 : $prevEnd}]
        } elseif {[string match -nocase "after *" $startTok]} {
            set refs [lrange [split $startTok] 1 end]
            set start 0.0; set any 0
            foreach r $refs {
                if {[dict exists $byId $r]} {
                    set re [dict get [dict get $byId $r] end]
                    if {!$any || $re > $start} { set start $re }
                    set any 1
                }
            }
            if {!$any} { set start [expr {$prevEnd eq "" ? 0.0 : $prevEnd}] }
        } else {
            set start [_parseInstant $startTok $fmt]
        }

        # --- end ---
        if {$endTok eq ""} {
            set end $start
        } elseif {[_isDuration $endTok]} {
            set end [expr {$start + [_durationSecs $endTok]}]
        } else {
            set end [_parseInstant $endTok $fmt]
        }
        if {$end < $start} { set end $start }

        set id [dict get $t id]
        if {$id ne ""} { dict set byId $id [dict create start $start end $end] }
        set prevEnd $end

        lappend out [dict create \
            title [dict get $t title] section [dict get $t section] \
            tags $tags milestone $milestone start $start end $end]
    }
    return $out
}

# Choose ~nticks evenly spaced tick seconds across [lo,hi].
proc ::tclutils::tugantt::_x {s lo hi x0 w} {
    return [expr {$x0 + ($s-$lo)/double($hi-$lo)*$w}]
}

proc ::tclutils::tugantt::_ticks {lo hi nticks} {
    if {$hi <= $lo} { return [list $lo] }
    set out {}
    for {set i 0} {$i <= $nticks} {incr i} {
        lappend out [expr {$lo + ($hi-$lo)*$i/double($nticks)}]
    }
    return $out
}

# --- draw --------------------------------------------------------------------

proc ::tclutils::tugantt::_draw {c model o gfont} {
    variable colors
    set W  [$c width]
    set H  [$c height]
    set gs [dict get $o -scale]

    set tasks [_resolve $model]
    set fmt   [dict get $model dateFormat]
    set title [dict get $model title]
    set axisFmt [dict get $model axisFormat]
    if {$axisFmt eq ""} { set axisFmt [dict get $model dateFormat] }

    # overall time span
    set lo ""; set hi ""
    foreach t $tasks {
        set s [dict get $t start]; set e [dict get $t end]
        if {$lo eq "" || $s < $lo} { set lo $s }
        if {$hi eq "" || $e > $hi} { set hi $e }
    }
    if {$lo eq ""} { _err EMPTY "gantt has no datable tasks" }
    if {$hi <= $lo} { set hi [expr {$lo + 86400.0}] }

    # geometry (all fixed sizes * gs)
    set padX    [expr {12*$gs}]
    set padTop  [expr {($title ne "" ? 34 : 16)*$gs}]
    set padBot  [expr {22*$gs}]    ;# axis labels
    set labelW  [expr {150*$gs}]   ;# left column for section / task labels
    set rowH    [expr {20*$gs}]
    set barGap  [expr {6*$gs}]
    set fs      $gs

    set plotX0 [expr {$padX + $labelW}]
    set plotX1 [expr {$W - $padX}]
    set plotW  [expr {$plotX1 - $plotX0}]
    if {$plotW < 20} { set plotW 20; set plotX1 [expr {$plotX0+20}] }
    set plotY0 $padTop
    set n [llength $tasks]
    set rowStride [expr {$rowH + $barGap}]

    # title
    if {$title ne ""} {
        set tw [$c textwidth $title -scale $fs]
        _drawText $c $gfont $fs [expr {int(($W-$tw)/2.0)}] [expr {int(4*$gs)}] $title [dict get $colors text]
    }

    # vertical grid + axis labels
    set gridC [dict get $colors grid]
    set yAxis0 $plotY0
    set yAxis1 [expr {$plotY0 + $n*$rowStride}]
    foreach tk [_ticks $lo $hi 5] {
        set x [_x $tk $lo $hi $plotX0 $plotW]
        $c line [expr {int($x)}] [expr {int($yAxis0)}] [expr {int($x)}] [expr {int($yAxis1)}] \
            -color $gridC -width 1
        if {$fmt ne "X"} {
            set lbl [clock format [expr {int($tk)}] -format [_clockFmt $axisFmt] -gmt 1]
        } else {
            set lbl [format %.0f $tk]
        }
        set lw [$c textwidth $lbl -scale $fs]
        _drawText $c $gfont $fs [expr {int($x-$lw/2.0)}] [expr {int($yAxis1+4*$gs)}] $lbl [dict get $colors text]
    }

    # rows: section background bands + bars + labels
    set row 0
    set lastSection "\u0000"
    set secIdx -1
    foreach t $tasks {
        set y [expr {$plotY0 + $row*$rowStride}]
        set sec [dict get $t section]
        if {$sec ne $lastSection} {
            incr secIdx
            set lastSection $sec
            # section label at the left
            if {$sec ne ""} {
                _drawText $c $gfont $fs [expr {int($padX)}] [expr {int($y+($rowH-8*$gs)/2.0)}] \
                    $sec [dict get $colors text]
            }
        }
        # alternating section background across the plot area
        set bg [expr {$secIdx % 2 ? [dict get $colors sectionB] : [dict get $colors sectionA]}]
        $c rect [expr {int($plotX0)}] [expr {int($y)}] [expr {int($plotX1)}] [expr {int($y+$rowH)}] \
            -fill 1 -fillcolor $bg -outline 0

        set s [dict get $t start]; set e [dict get $t end]
        set tags [dict get $t tags]
        set col [dict get $colors normal]
        if {"done" in $tags}   { set col [dict get $colors done] }
        if {"active" in $tags} { set col [dict get $colors active] }
        if {"crit" in $tags}   { set col [dict get $colors crit] }

        if {[dict get $t milestone]} {
            # diamond at the midpoint
            set mid [expr {($s+$e)/2.0}]
            set mx [_x $mid $lo $hi $plotX0 $plotW]
            set my [expr {$y + $rowH/2.0}]
            set r [expr {$rowH/2.0 - 1*$gs}]
            $c polygon [list \
                [expr {int($mx)}] [expr {int($my-$r)}] \
                [expr {int($mx+$r)}] [expr {int($my)}] \
                [expr {int($mx)}] [expr {int($my+$r)}] \
                [expr {int($mx-$r)}] [expr {int($my)}]] \
                -fill 1 -fillcolor [dict get $colors milestone] -outline 0
        } else {
            set bx0 [_x $s $lo $hi $plotX0 $plotW]
            set bx1 [_x $e $lo $hi $plotX0 $plotW]
            if {$bx1 - $bx0 < 2*$gs} { set bx1 [expr {$bx0 + 2*$gs}] }
            set by0 [expr {$y + 2*$gs}]
            set by1 [expr {$y + $rowH - 2*$gs}]
            $c rect [expr {int($bx0)}] [expr {int($by0)}] [expr {int($bx1)}] [expr {int($by1)}] \
                -fill 1 -fillcolor $col -outline 1 -color [dict get $colors bar_outline]
        }

        # task title to the right of the bar (or left if it would overflow)
        set ttl [dict get $t title]
        set tw [$c textwidth $ttl -scale $fs]
        set lblY [expr {int($y+($rowH-8*$gs)/2.0)}]
        set ex [_x $e $lo $hi $plotX0 $plotW]
        if {$ex + 4*$gs + $tw <= $plotX1} {
            _drawText $c $gfont $fs [expr {int($ex+4*$gs)}] $lblY $ttl [dict get $colors text]
        } else {
            set sx [_x $s $lo $hi $plotX0 $plotW]
            _drawText $c $gfont $fs [expr {int($sx-4*$gs-$tw)}] $lblY $ttl [dict get $colors text]
        }
        incr row
    }
}

# --- backends ----------------------------------------------------------------

proc ::tclutils::tugantt::toSvg {model args} {
    set o [_opts {*}$args]
    package require tclutils::tusvg 0.2
    set c [::tclutils::tusvg::new \
        -width [dict get $o -width] -height [dict get $o -height] -background white]
    _draw $c $model $o ""
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tugantt::toPng {model args} {
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

proc ::tclutils::tugantt::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tugantt::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tugantt 0.1
