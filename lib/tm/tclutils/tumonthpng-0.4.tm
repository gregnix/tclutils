# tclutils::tumonthpng -- render a month calendar to a PNG image, mirroring the
# look of the monthcanvas Tk widget (themes, week numbers, weekday header,
# today/weekend/holiday/note/other-month cell states). Pure Tcl: the month grid
# is computed with the core clock command (no Tk, no gel::calendar); drawing is
# done with tclutils::tupngdraw.
#
# An export adapter: year+month (+ optional holidays/notes/today) -> PNG.
#
#   package require tclutils::tumonthpng
#   tclutils::tumonthpng::write june.png 2026 6 \
#       -today 2026-06-06 \
#       -holidays {2026-06-08 "Pfingstmontag"} \
#       -notes    {2026-06-15 "Zahnarzt"} \
#       -select {2026-06-08 2026-06-12..2026-06-15} -selectstyle both \
#       -theme default
#
# Dates are ISO yyyy-mm-dd. Week numbers are ISO-8601 (%V). The grid is six
# weeks, Monday-first by default (-firstweekday). Holidays and notes are dicts
# keyed by date; their values (names/text) are used only to flag the cell.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tupngdraw 0.12

namespace eval ::tclutils {}
namespace eval ::tclutils::tumonthpng {
    namespace export render write renderQuarter writeQuarter renderYear writeYear
    variable version 0.3
    variable themes
}

# --- themes (ported from monthcanvas) ---------------------------------------
set ::tclutils::tumonthpng::themes(default) {
    bg white  dayBg white  dayFg black  dayOutline #e0e0e0
    todayBg #90EE90  todayFg #006400  todayOutline #228B22
    holidayBg #FFE4E1  holidayFg #8B0000  holidayOutline #CD5C5C
    weekendBg #F0F8FF  weekendFg #4169E1
    otherMonthBg #F5F5F5  otherMonthFg #A0A0A0
    noteBg #FFFACD  noteFg #000000  noteMarker #FF6347
    weeknrBg #F8F8F8  weeknrFg #606060
    headerBg #E8E8E8  headerFg #333333  titleFg #1a1a1a
}
set ::tclutils::tumonthpng::themes(dark) {
    bg #2d2d2d  dayBg #3d3d3d  dayFg #e0e0e0  dayOutline #505050
    todayBg #2E8B57  todayFg #FFFFFF  todayOutline #3CB371
    holidayBg #8B4513  holidayFg #FFE4C4  holidayOutline #CD853F
    weekendBg #4a4a5a  weekendFg #87CEEB
    otherMonthBg #353535  otherMonthFg #707070
    noteBg #4a4a2a  noteFg #FFD700  noteMarker #FF6347
    weeknrBg #383838  weeknrFg #909090
    headerBg #404040  headerFg #c0c0c0  titleFg #ffffff
}
set ::tclutils::tumonthpng::themes(light) {
    bg #fafafa  dayBg #ffffff  dayFg #333333  dayOutline #d0d0d0
    todayBg #4CAF50  todayFg #ffffff  todayOutline #388E3C
    holidayBg #FFCDD2  holidayFg #C62828  holidayOutline #EF9A9A
    weekendBg #E3F2FD  weekendFg #1565C0
    otherMonthBg #f0f0f0  otherMonthFg #b0b0b0
    noteBg #FFF9C4  noteFg #F57F17  noteMarker #FF5722
    weeknrBg #f5f5f5  weeknrFg #757575
    headerBg #e0e0e0  headerFg #424242  titleFg #212121
}

proc ::tclutils::tumonthpng::_theme {name} {
    variable themes
    if {![info exists themes($name)]} {
        return -code error -errorcode {TCLUTILS TUMONTHPNG THEME} \
            "unknown theme: $name (have default|dark|light)"
    }
    return $themes($name)
}

# Six-week grid (Monday-first by default). Returns a list of 42 day-dicts:
#   date (yyyy-mm-dd) day (1..31) weeknr (ISO) weekday (1=Mon..7=Sun)
#   current (1 if in this month) today (1 if == $today)
proc ::tclutils::tumonthpng::_grid {year month firstweekday today} {
    set first [clock scan [format %04d-%02d-01 $year $month] \
        -format %Y-%m-%d -gmt 1]
    set wd [clock format $first -format %u -gmt 1]
    set back [expr {($wd - $firstweekday + 7) % 7}]
    set start [clock add $first -$back days -gmt 1]
    set out {}
    for {set i 0} {$i < 42} {incr i} {
        set d [clock add $start $i days -gmt 1]
        set date [clock format $d -format %Y-%m-%d -gmt 1]
        set dnum [scan [clock format $d -format %d -gmt 1] %d]
        set wnr  [scan [clock format $d -format %V -gmt 1] %d]
        set wday [clock format $d -format %u -gmt 1]
        set mon  [scan [clock format $d -format %m -gmt 1] %d]
        lappend out [dict create date $date day $dnum weeknr $wnr \
            weekday $wday current [expr {$mon == $month}] \
            today [expr {$date eq $today}]]
    }
    return $out
}

# geometry (px) for one month block, derived from scale
proc ::tclutils::tumonthpng::_geom {s showweeks} {
    set cw [expr {26 * $s}]
    set ch [expr {20 * $s}]
    set lw [expr {$showweeks ? 20 * $s : 0}]
    set titleH  [expr {18 * $s}]
    set headerH [expr {16 * $s}]
    set topH [expr {$titleH + $headerH}]
    return [dict create cw $cw ch $ch lw $lw titleH $titleH headerH $headerH \
        topH $topH blockW [expr {$lw + 7 * $cw}] blockH [expr {$topH + 6 * $ch}] \
        gap [expr {10 * $s}]]
}

# Draw one month block at offset (x0,y0) onto an existing tupngdraw image.
# titleText is the heading for this block ("<MonthName> <year>"). Returns the
# block size {w h}. With x0=y0=0 this reproduces the single-month layout exactly.
proc ::tclutils::tumonthpng::_blend {c1 c2 a} {
    # a in 0..1 ; returns c1*(1-a) + c2*a as #rrggbb. Colours go through
    # tupngdraw::_color so names ("white"), #rgb, #rrggbb(aa) and {r g b} all work.
    lassign [::tclutils::tupngdraw::_color $c1] r1 g1 b1
    lassign [::tclutils::tupngdraw::_color $c2] r2 g2 b2
    return [format #%02x%02x%02x \
        [expr {int($r1*(1-$a) + $r2*$a + 0.5)}] \
        [expr {int($g1*(1-$a) + $g2*$a + 0.5)}] \
        [expr {int($b1*(1-$a) + $b2*$a + 0.5)}]]
}

# Expand a -select option (list of YYYY-MM-DD and YYYY-MM-DD..YYYY-MM-DD ranges)
# into a dict whose keys are the individual ISO dates.
proc ::tclutils::tumonthpng::_selectSet {sel} {
    set out {}
    foreach tok $sel {
        if {[regexp {^(\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2})$} $tok -> a b]} {
            set t [clock scan $a -format %Y-%m-%d -gmt 1]
            set e [clock scan $b -format %Y-%m-%d -gmt 1]
            if {$e < $t} { set tmp $t; set t $e; set e $tmp }
            for {} {$t <= $e} {incr t 86400} {
                dict set out [clock format $t -format %Y-%m-%d -gmt 1] 1
            }
        } elseif {[regexp {^\d{4}-\d{2}-\d{2}$} $tok]} {
            dict set out $tok 1
        } else {
            return -code error -errorcode {TCLUTILS TUMONTHPNG SELECT} \
                "invalid -select entry: $tok (use YYYY-MM-DD or YYYY-MM-DD..YYYY-MM-DD)"
        }
    }
    return $out
}

proc ::tclutils::tumonthpng::_drawMonthOn {img x0 y0 year month titleText th s o today holidays notes} {
    set tcmd [dict get $o -textcmd]
    set g [_geom $s [dict get $o -showweeks]]
    set selset   [_selectSet [dict get $o -select]]
    set selStyle [dict get $o -selectstyle]
    if {$selStyle ni {outline fill both}} {
        return -code error -errorcode {TCLUTILS TUMONTHPNG SELECTSTYLE} \
            "-selectstyle must be outline|fill|both"
    }
    set selColor [dict get $o -selectcolor]; if {$selColor eq ""} { set selColor #1565C0 }
    set selW [dict get $o -selectwidth];     if {$selW eq ""}     { set selW [expr {max(2, $s)}] }
    set selA [dict get $o -selectalpha]
    dict with g {}  ;# -> cw ch lw titleH headerH topH blockW blockH gap

    MyCentre $img [expr {$x0 + $lw}] $y0 [expr {7 * $cw}] $titleH \
        $titleText [dict get $th titleFg] $s $tcmd

    set hy [expr {$y0 + $titleH}]
    if {$lw > 0} {
        $img setfill [dict get $th headerBg]
        $img rect $x0 $hy [expr {$x0 + $lw - 1}] [expr {$hy + $headerH - 1}] -fill 1 -outline 0
        MyCentre $img $x0 $hy $lw $headerH "KW" [dict get $th headerFg] $s $tcmd
    }
    for {set c 0} {$c < 7} {incr c} {
        set hx [expr {$x0 + $lw + $c * $cw}]
        $img setfill [dict get $th headerBg]
        $img rect $hx $hy [expr {$hx + $cw - 1}] [expr {$hy + $headerH - 1}] -fill 1 -outline 0
        MyCentre $img $hx $hy $cw $headerH [lindex [dict get $o -weekdays] $c] \
            [dict get $th headerFg] $s $tcmd
    }

    set grid [_grid $year $month [dict get $o -firstweekday] $today]
    for {set row 0} {$row < 6} {incr row} {
        set wkDrawn 0
        for {set col 0} {$col < 7} {incr col} {
            set day [lindex $grid [expr {$row * 7 + $col}]]
            set date [dict get $day date]
            set isToday   [dict get $day today]
            set isCurrent [dict get $day current]
            set isHoliday [dict exists $holidays $date]
            set isWeekend [expr {[dict get $day weekday] in {6 7}}]
            set hasNote   [dict exists $notes $date]

            if {$lw > 0 && !$wkDrawn} {
                set wx $x0
                set wy [expr {$y0 + $topH + $row * $ch}]
                $img setfill [dict get $th weeknrBg]
                $img rect $wx $wy [expr {$wx + $lw - 1}] [expr {$wy + $ch - 1}] -fill 1 -outline 0
                MyCentre $img $wx $wy $lw $ch \
                    [format %02d [dict get $day weeknr]] [dict get $th weeknrFg] $s $tcmd
                set wkDrawn 1
            }

            if {$isToday} {
                set bg [dict get $th todayBg]; set fg [dict get $th todayFg]
                set ol [dict get $th todayOutline]
            } elseif {$isHoliday} {
                set bg [dict get $th holidayBg]; set fg [dict get $th holidayFg]
                set ol [dict get $th holidayOutline]
            } elseif {$hasNote} {
                set bg [dict get $th noteBg]; set fg [dict get $th noteFg]
                set ol [dict get $th dayOutline]
            } elseif {!$isCurrent} {
                set bg [dict get $th otherMonthBg]; set fg [dict get $th otherMonthFg]
                set ol [dict get $th dayOutline]
            } elseif {$isWeekend} {
                set bg [dict get $th weekendBg]; set fg [dict get $th weekendFg]
                set ol [dict get $th dayOutline]
            } else {
                set bg [dict get $th dayBg]; set fg [dict get $th dayFg]
                set ol [dict get $th dayOutline]
            }

            set dx [expr {$x0 + $lw + $col * $cw}]
            set dy [expr {$y0 + $topH + $row * $ch}]
            set isSel [dict exists $selset $date]
            if {$isSel && $selStyle in {fill both}} {
                set bg [_blend $bg $selColor $selA]
            }
            $img setfill $bg
            $img setstroke $ol
            $img setlinewidth 1
            $img rect $dx $dy [expr {$dx + $cw - 1}] [expr {$dy + $ch - 1}] -fill 1
            MyCentre $img $dx $dy $cw $ch [dict get $day day] $fg $s $tcmd

            if {$hasNote} {
                $img setfill [dict get $th noteMarker]
                $img circle [expr {$dx + $cw - 4 * $s}] [expr {$dy + 4 * $s}] \
                    [expr {2 * $s}] -fill 1 -outline 0
            }
            if {$isSel && $selStyle in {outline both}} {
                $img setlinewidth $selW
                $img rect $dx $dy [expr {$dx + $cw - 1}] [expr {$dy + $ch - 1}] \
                    -fill 0 -outline 1 -color $selColor
            }
        }
    }
    return [list [dict get $g blockW] [dict get $g blockH]]
}

proc ::tclutils::tumonthpng::render {year month args} {
    set o [::tclutils::common::parseOptions {
        -theme default -scale 2 -today {} -holidays {} -notes {}
        -firstweekday 1 -showweeks 1 -textcmd {}
        -select {} -selectcolor {} -selectwidth {} -selectstyle outline -selectalpha 0.3
        -weekdays {Mo Di Mi Do Fr Sa So}
        -monthnames {Januar Februar M\u00e4rz April Mai Juni Juli August
                     September Oktober November Dezember}
        -title {}
    } {*}$args]
    set year  [scan $year %d]
    set month [scan $month %d]
    if {$month < 1 || $month > 12} {
        return -code error -errorcode {TCLUTILS TUMONTHPNG MONTH} \
            "month must be 1..12"
    }
    set tcmd [dict get $o -textcmd]
    set th [_theme [dict get $o -theme]]
    set s  [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]
    ::tclutils::common::ensureBoolean [dict get $o -showweeks] -showweeks
    set fwd [dict get $o -firstweekday]
    set today [dict get $o -today]
    if {$today eq ""} { set today [clock format [clock seconds] -format %Y-%m-%d] }
    set holidays [dict get $o -holidays]
    set notes    [dict get $o -notes]

    set g [_geom $s [dict get $o -showweeks]]
    set img [::tclutils::tupngdraw::new -width [dict get $g blockW] \
        -height [dict get $g blockH] -background [dict get $th bg]]
    set monthName [lindex [dict get $o -monthnames] [expr {$month - 1}]]
    set title [expr {[dict get $o -title] ne "" ? [dict get $o -title] : "$monthName $year"}]
    _drawMonthOn $img 0 0 $year $month $title $th $s $o $today $holidays $notes
    set png [$img data -compression 9]
    $img destroy
    return $png
}

# centre a short string in a cell (top-left x,y; width cw, height ch)
proc ::tclutils::tumonthpng::MyCentre {img x y cw ch text color scale {tcmd {}}} {
    if {$tcmd ne ""} {
        # Delegate drawing of "text" centred in the box (x,y,cw,ch) to the
        # caller-supplied command, e.g. an outline-font renderer. It is free to
        # choose its own pixel size from the box height.
        {*}$tcmd $img $x $y $cw $ch $text $color
        return
    }
    set tw [expr {[string length $text] * 6 * $scale}]
    set thh [expr {8 * $scale}]
    $img text [expr {$x + ($cw - $tw) / 2}] [expr {$y + ($ch - $thh) / 2}] \
        $text -color $color -scale $scale
    return
}

proc ::tclutils::tumonthpng::write {file year month args} {
    set png [render $year $month {*}$args]
    set fid [open $file w]
    fconfigure $fid -translation binary
    puts -nonewline $fid $png
    close $fid
    return $file
}


# --- quarter (3 consecutive months) ----------------------------------------
proc ::tclutils::tumonthpng::renderQuarter {year month args} {
    set o [::tclutils::common::parseOptions {
        -theme default -scale 2 -today {} -holidays {} -notes {}
        -firstweekday 1 -showweeks 1 -textcmd {}
        -select {} -selectcolor {} -selectwidth {} -selectstyle outline -selectalpha 0.3
        -weekdays {Mo Di Mi Do Fr Sa So}
        -monthnames {Januar Februar M\u00e4rz April Mai Juni Juli August
                     September Oktober November Dezember}
        -title {}
    } {*}$args]
    set year  [scan $year %d]
    set month [scan $month %d]
    if {$month < 1 || $month > 12} {
        return -code error -errorcode {TCLUTILS TUMONTHPNG MONTH} "month must be 1..12"
    }
    set th [_theme [dict get $o -theme]]
    set s  [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]
    ::tclutils::common::ensureBoolean [dict get $o -showweeks] -showweeks
    set today [dict get $o -today]
    if {$today eq ""} { set today [clock format [clock seconds] -format %Y-%m-%d] }
    set holidays [dict get $o -holidays]
    set notes    [dict get $o -notes]
    set names    [dict get $o -monthnames]

    set g [_geom $s [dict get $o -showweeks]]
    set bw [dict get $g blockW]; set bh [dict get $g blockH]; set gap [dict get $g gap]
    set img [::tclutils::tupngdraw::new -width [expr {3 * $bw + 2 * $gap}] \
        -height $bh -background [dict get $th bg]]
    for {set i 0} {$i < 3} {incr i} {
        set m [expr {$month + $i}]; set y $year
        while {$m > 12} { incr m -12; incr y }
        set title "[lindex $names [expr {$m - 1}]] $y"
        _drawMonthOn $img [expr {$i * ($bw + $gap)}] 0 $y $m $title \
            $th $s $o $today $holidays $notes
    }
    set png [$img data -compression 9]
    $img destroy
    return $png
}

# --- year (12 months, -cols columns; default 3) -----------------------------
proc ::tclutils::tumonthpng::renderYear {year args} {
    set o [::tclutils::common::parseOptions {
        -theme default -scale 2 -today {} -holidays {} -notes {}
        -firstweekday 1 -showweeks 1 -textcmd {} -cols 3
        -select {} -selectcolor {} -selectwidth {} -selectstyle outline -selectalpha 0.3
        -weekdays {Mo Di Mi Do Fr Sa So}
        -monthnames {Januar Februar M\u00e4rz April Mai Juni Juli August
                     September Oktober November Dezember}
        -title {}
    } {*}$args]
    set year [scan $year %d]
    set th [_theme [dict get $o -theme]]
    set s  [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]
    set cols [::tclutils::common::ensurePositiveInteger [dict get $o -cols] -cols]
    ::tclutils::common::ensureBoolean [dict get $o -showweeks] -showweeks
    set today [dict get $o -today]
    if {$today eq ""} { set today [clock format [clock seconds] -format %Y-%m-%d] }
    set holidays [dict get $o -holidays]
    set notes    [dict get $o -notes]
    set names    [dict get $o -monthnames]

    set rows [expr {(12 + $cols - 1) / $cols}]
    set g [_geom $s [dict get $o -showweeks]]
    set bw [dict get $g blockW]; set bh [dict get $g blockH]; set gap [dict get $g gap]
    set W [expr {$cols * $bw + ($cols - 1) * $gap}]
    set H [expr {$rows * $bh + ($rows - 1) * $gap}]
    set img [::tclutils::tupngdraw::new -width $W -height $H -background [dict get $th bg]]
    for {set m 1} {$m <= 12} {incr m} {
        set col [expr {($m - 1) % $cols}]
        set row [expr {($m - 1) / $cols}]
        set title "[lindex $names [expr {$m - 1}]] $year"
        _drawMonthOn $img [expr {$col * ($bw + $gap)}] [expr {$row * ($bh + $gap)}] \
            $year $m $title $th $s $o $today $holidays $notes
    }
    set png [$img data -compression 9]
    $img destroy
    return $png
}

proc ::tclutils::tumonthpng::writeQuarter {file year month args} {
    set png [renderQuarter $year $month {*}$args]
    set fid [open $file w]; fconfigure $fid -translation binary
    puts -nonewline $fid $png; close $fid; return $file
}
proc ::tclutils::tumonthpng::writeYear {file year args} {
    set png [renderYear $year {*}$args]
    set fid [open $file w]; fconfigure $fid -translation binary
    puts -nonewline $fid $png; close $fid; return $file
}

package provide tclutils::tumonthpng 0.4
