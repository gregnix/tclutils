# tclutils::tucal -- cal-like calendar output in pure Tcl
# Description: cal-like calendar output in pure Tcl
# Category: Date · time/calendar
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucal {
    namespace export month year three now render
    variable version 0.2
}

proc ::tclutils::tucal::_options {args} {
    set defaults [dict create -mondayfirst 0 -weeknumbers 0 -iso 0 -locale {}]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    if {[::tclutils::common::ensureBoolean [dict get $opts -iso] -iso]} {
        dict set opts -mondayfirst 1
        dict set opts -weeknumbers 1
    }
    return $opts
}

proc ::tclutils::tucal::_splitOptions {argsVar} {
    upvar 1 $argsVar args
    set positional {}
    set optionArgs {}
    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        if {[string match -* $a]} {
            lappend optionArgs $a
            incr i
            if {$i >= [llength $args]} {
                return -code error -errorcode {TCLUTILS TUCAL OPTION} "missing value for option \"$a\""
            }
            lappend optionArgs [lindex $args $i]
        } else {
            lappend positional $a
        }
        incr i
    }
    set args $positional
    return $optionArgs
}

proc ::tclutils::tucal::_center {text width} {
    set len [string length $text]
    if {$len >= $width} { return $text }
    set pad [expr {$width - $len}]
    set left [expr {$pad / 2}]
    return [string repeat " " $left]$text[string repeat " " [expr {$pad - $left}]]
}

proc ::tclutils::tucal::_monthSeconds {year month day} {
    clock scan [::format %04d-%02d-%02d $year $month $day] -format %Y-%m-%d -timezone :UTC
}

proc ::tclutils::tucal::_validateMonth {month} {
    if {![string is integer -strict $month] || $month < 1 || $month > 12} {
        return -code error -errorcode {TCLUTILS TUCAL MONTH} "invalid month $month"
    }
}

proc ::tclutils::tucal::_validateYear {year} {
    if {![string is integer -strict $year] || $year < 1} {
        return -code error -errorcode {TCLUTILS TUCAL YEAR} "invalid year $year"
    }
}

proc ::tclutils::tucal::_daysInMonth {year month} {
    set end [clock add [_monthSeconds $year $month 1] 1 month -timezone :UTC]
    scan [clock format [clock add $end -1 day -timezone :UTC] -format %d -timezone :UTC] %d d
    return $d
}

proc ::tclutils::tucal::_startColumn {year month mondayfirst} {
    set t [_monthSeconds $year $month 1]
    if {$mondayfirst} {
        scan [clock format $t -format %u -timezone :UTC] %d col
        return [expr {$col - 1}]
    }
    scan [clock format $t -format %w -timezone :UTC] %d col
    return $col
}

proc ::tclutils::tucal::_clockFormat {seconds format locale} {
    if {$locale eq ""} {
        return [clock format $seconds -format $format -timezone :UTC]
    }
    return [clock format $seconds -format $format -timezone :UTC -locale $locale]
}

proc ::tclutils::tucal::_headers {mondayfirst locale} {
    if {$locale eq ""} {
        if {$mondayfirst} {
            return {Mo Tu We Th Fr Sa Su}
        }
        return {Su Mo Tu We Th Fr Sa}
    }
    if {$mondayfirst} {
        set base [_monthSeconds 2020 1 6]
    } else {
        set base [_monthSeconds 2020 1 5]
    }
    set headers {}
    for {set i 0} {$i < 7} {incr i} {
        set t [clock add $base [expr {$i * 86400}] seconds -timezone :UTC]
        lappend headers [_clockFormat $t %a $locale]
    }
    return $headers
}

proc ::tclutils::tucal::_monthTitle {year month locale} {
    _clockFormat [_monthSeconds $year $month 15] "%B %Y" $locale
}

proc ::tclutils::tucal::_weekNumber {year month day mondayfirst} {
    set t [_monthSeconds $year $month $day]
    if {$mondayfirst} {
        return [clock format $t -format %V -timezone :UTC]
    }
    return [clock format $t -format %U -timezone :UTC]
}

proc ::tclutils::tucal::_formatRow {year month rowDays weeknumbers mondayfirst cellWidth} {
    set parts {}
    foreach d $rowDays {
        if {$d eq ""} {
            lappend parts [string repeat " " $cellWidth]
        } else {
            lappend parts [::format %*d $cellWidth $d]
        }
    }
    set line [join $parts " "]
    if {!$weeknumbers} {
        return $line
    }
    set wn ""
    foreach d $rowDays {
        if {$d ne ""} {
            set wn [_weekNumber $year $month $d $mondayfirst]
            break
        }
    }
    if {$wn eq ""} {
        return [::format "%2s  %s" "" $line]
    }
    return [::format "%2s  %s" $wn $line]
}

proc ::tclutils::tucal::_renderMonthBody {year month opts {compact 0}} {
    set mondayfirst [::tclutils::common::ensureBoolean [dict get $opts -mondayfirst] -mondayfirst]
    set weeknumbers [::tclutils::common::ensureBoolean [dict get $opts -weeknumbers] -weeknumbers]
    set locale [dict get $opts -locale]
    set startCol [_startColumn $year $month $mondayfirst]
    set days [_daysInMonth $year $month]
    set cellWidth [expr {$compact ? 2 : 3}]

    set lines {}
    set header [_headers $mondayfirst $locale]
    # Pad each weekday name to the column width so the header lines up with the
    # right-aligned day numbers below it.
    set hcells {}
    foreach name $header {
        lappend hcells [::format %*s $cellWidth $name]
    }
    set headerLine [join $hcells " "]
    if {$weeknumbers} {
        lappend lines [::format "%2s  %s" "" $headerLine]
    } else {
        lappend lines $headerLine
    }

    set day 1
    set rowDays {}
    for {set cell 0} {$cell < $startCol} {incr cell} {
        lappend rowDays ""
    }
    while {$day <= $days} {
        lappend rowDays $day
        incr day
        if {[llength $rowDays] == 7} {
            lappend lines [_formatRow $year $month $rowDays $weeknumbers $mondayfirst $cellWidth]
            set rowDays {}
        }
    }
    if {[llength $rowDays] > 0} {
        while {[llength $rowDays] < 7} { lappend rowDays "" }
        lappend lines [_formatRow $year $month $rowDays $weeknumbers $mondayfirst $cellWidth]
    }
    return $lines
}

# _block -- one month as a list of lines: the title centred over the day
# columns (after the week-number column, if any), the header, the weeks.
# Lines carry no trailing blanks. Returns {width lines}; width is the width of
# the full grid (7 cells and 6 gaps, plus 4 for week numbers), or the longest
# line if a title is wider.
proc ::tclutils::tucal::_block {year month opts {compact 0}} {
    set weeknumbers [::tclutils::common::ensureBoolean [dict get $opts -weeknumbers] -weeknumbers]
    set cellWidth [expr {$compact ? 2 : 3}]
    set daysWidth [expr {7 * $cellWidth + 6}]
    set prefix [expr {$weeknumbers ? "    " : ""}]
    set title [_monthTitle $year $month [dict get $opts -locale]]
    set lines [list $prefix[_center $title $daysWidth]]
    lappend lines {*}[_renderMonthBody $year $month $opts $compact]
    set width [expr {$daysWidth + [string length $prefix]}]
    set out {}
    foreach line $lines {
        set line [string trimright $line]
        if {[string length $line] > $width} { set width [string length $line] }
        lappend out $line
    }
    return [list $width $out]
}

# _side -- set blocks side by side, each padded to the widest block, two
# blanks between them, no trailing blanks.
proc ::tclutils::tucal::_side {blocks} {
    set width 0
    set max 0
    foreach b $blocks {
        lassign $b w lines
        if {$w > $width} { set width $w }
        if {[llength $lines] > $max} { set max [llength $lines] }
    }
    set out {}
    for {set ln 0} {$ln < $max} {incr ln} {
        set parts {}
        foreach b $blocks {
            lappend parts [::format %-*s $width [lindex $b 1 $ln]]
        }
        lappend out [string trimright [join $parts "  "]]
    }
    return [list $width $out]
}

proc ::tclutils::tucal::render {year month args} {
    _validateYear $year
    _validateMonth $month
    set opts [_options {*}$args]
    return [join [lindex [_block $year $month $opts] 1] \n]
}

proc ::tclutils::tucal::_resolveMonthYear {argsVar} {
    upvar 1 $argsVar args
    switch [llength $args] {
        0 {
            scan [clock format [clock seconds] -format %Y-%m -timezone :UTC] %4d-%2d year month
        }
        1 {
            set month [lindex $args 0]
            scan [clock format [clock seconds] -format %Y -timezone :UTC] %d year
        }
        2 {
            set month [lindex $args 0]
            set year [lindex $args 1]
        }
        default {
            return -code error -errorcode {TCLUTILS TUCAL ARGS} "too many arguments"
        }
    }
    _validateMonth $month
    _validateYear $year
    return [list $year $month]
}

proc ::tclutils::tucal::month {args} {
    set optArgs [_splitOptions args]
    set opts [_options {*}$optArgs]

    if {[llength $args] == 1} {
        set a [lindex $args 0]
        if {[string is integer -strict $a] && $a >= 1900 && [string length $a] == 4} {
            return [year $a {*}$optArgs]
        }
    }

    lassign [_resolveMonthYear args] year month
    return [render $year $month {*}$optArgs]
}

proc ::tclutils::tucal::now {args} {
    month {*}$args
}

# year -- twelve months in four rows of three, read row by row like cal:
# January February March in the first row.
proc ::tclutils::tucal::year {year args} {
    set opts [_options {*}$args]
    _validateYear $year
    set blocks {}
    for {set m 1} {$m <= 12} {incr m} {
        lappend blocks [_block $year $m $opts 1]
    }
    set rows {}
    set width 0
    for {set row 0} {$row < 4} {incr row} {
        set first [expr {$row * 3}]
        lassign [_side [lrange $blocks $first [expr {$first + 2}]]] w lines
        lappend rows $lines
        if {$w > $width} { set width $w }
    }
    set total [expr {3 * $width + 4}]
    set out [list [string trimright [_center $year $total]] ""]
    foreach lines $rows {
        lappend out {*}$lines ""
    }
    return [string trimright [join $out \n]]
}

proc ::tclutils::tucal::three {args} {
    set optArgs [_splitOptions args]
    set opts [_options {*}$optArgs]
    lassign [_resolveMonthYear args] year month

    set center [_monthSeconds $year $month 1]
    set prev [clock add $center -1 month -timezone :UTC]
    set next [clock add $center 1 month -timezone :UTC]
    scan [clock format $prev -format %Y-%m -timezone :UTC] %4d-%2d py pm
    scan [clock format $next -format %Y-%m -timezone :UTC] %4d-%2d ny nm

    set blocks {}
    foreach {y m} [list $py $pm $year $month $ny $nm] {
        lappend blocks [_block $y $m $opts]
    }
    return [join [lindex [_side $blocks] 1] \n]
}

package provide tclutils::tucal 0.2
