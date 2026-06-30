# tclutils::turrule -- expand iCalendar RRULE recurrence rules into occurrences.
# Description: expand iCalendar RRULE recurrence rules into occurrences.
# Category: Date · time/calendar
#
# Supported subset of RFC 5545: FREQ DAILY/WEEKLY/MONTHLY/YEARLY, INTERVAL,
# COUNT, UNTIL, BYDAY (weekday list for WEEKLY; ordinal forms like 1MO/-1FR for
# MONTHLY/YEARLY) and BYMONTHDAY (day list, negatives count from month end).
# Not supported: BYSETPOS, BYWEEKNO, BYYEARDAY, BYMONTH, non-default WKST.
# All date math is done in UTC so results are calendar-stable. Tcl 8.6+ and 9.x.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::turrule {
    namespace export parse occurrences eventsInRange
    variable version 0.1
    variable DOW {MO 1 TU 2 WE 3 TH 4 FR 5 SA 6 SU 7}
}

# Parse an RRULE string into a dict of upper-case parts.
proc ::tclutils::turrule::parse {rr} {
    set d [dict create]
    foreach part [split [string trim $rr] ";"] {
        if {$part eq ""} continue
        set i [string first = $part]
        if {$i < 0} continue
        dict set d [string toupper [string range $part 0 $i-1]] \
            [string range $part $i+1 end]
    }
    return $d
}

# --- date helpers (UTC) --------------------------------------------------

proc ::tclutils::turrule::_isDateOnly {s} { return [expr {![string match *T* $s]}] }

proc ::tclutils::turrule::_scan {s} {
    set s [string trim $s]
    if {[string match *Z $s]} { set s [string range $s 0 end-1] }
    foreach fmt {%Y%m%dT%H%M%S %Y-%m-%dT%H:%M:%S %Y%m%d %Y-%m-%d} {
        if {![catch {clock scan $s -format $fmt -gmt 1} e]} { return $e }
    }
    return -code error -errorcode {TCLUTILS TURRULE DATE} "cannot parse date: \"$s\""
}

proc ::tclutils::turrule::_fmt {epoch dateOnly} {
    return [clock format $epoch \
        -format [expr {$dateOnly ? "%Y-%m-%d" : "%Y-%m-%dT%H:%M:%S"}] -gmt 1]
}

proc ::tclutils::turrule::_midnight {epoch} { return [expr {$epoch - ($epoch % 86400)}] }
proc ::tclutils::turrule::_dow {epoch} { return [clock format $epoch -format %u -gmt 1] }

proc ::tclutils::turrule::_mkday {y m d} {
    return [clock scan [format %04d-%02d-%02d $y $m $d] -format %Y-%m-%d -gmt 1]
}

proc ::tclutils::turrule::_daysInMonth {y m} {
    set ny [expr {$m == 12 ? $y + 1 : $y}]
    set nm [expr {$m == 12 ? 1 : $m + 1}]
    set last [expr {[_mkday $ny $nm 1] - 86400}]
    return [scan [clock format $last -format %d -gmt 1] %d]
}

# weekday code -> 1..7
proc ::tclutils::turrule::_dowNum {code} {
    variable DOW
    return [dict get $DOW [string toupper $code]]
}

# Split a comma list, trimming blanks.
proc ::tclutils::turrule::_list {v} {
    set out {}
    foreach x [split $v ,] { if {$x ne ""} { lappend out $x } }
    return $out
}

# nth weekday-of-month epoch; ord>0 from start, ord<0 from end. "" if invalid.
proc ::tclutils::turrule::_nthDow {y m ord wd} {
    set dim [_daysInMonth $y $m]
    set days {}
    for {set d 1} {$d <= $dim} {incr d} {
        if {[_dow [_mkday $y $m $d]] == $wd} { lappend days $d }
    }
    if {$ord > 0} {
        set idx [expr {$ord - 1}]
    } else {
        set idx [expr {[llength $days] + $ord}]
    }
    if {$idx < 0 || $idx >= [llength $days]} { return "" }
    return [_mkday $y $m [lindex $days $idx]]
}

# --- candidate generation per period ------------------------------------

# Returns the midnight epochs for one MONTHLY/YEARLY period (year/month), as a
# sorted list, applying BYMONTHDAY / BYDAY(ordinal) or defaulting to $defday.
proc ::tclutils::turrule::_monthCandidates {y m rule defday} {
    set dim [_daysInMonth $y $m]
    set days {}
    if {[dict exists $rule BYMONTHDAY]} {
        foreach md [_list [dict get $rule BYMONTHDAY]] {
            set day [expr {$md > 0 ? $md : $dim + $md + 1}]
            if {$day >= 1 && $day <= $dim} { lappend days $day }
        }
    }
    set epochs {}
    if {[dict exists $rule BYDAY]} {
        foreach code [_list [dict get $rule BYDAY]] {
            if {[regexp {^([+-]?\d+)?([A-Za-z]{2})$} $code -> ord wd]} {
                if {$ord eq ""} {
                    # no ordinal: every matching weekday in the month
                    for {set d 1} {$d <= $dim} {incr d} {
                        if {[_dow [_mkday $y $m $d]] == [_dowNum $wd]} {
                            lappend epochs [_mkday $y $m $d]
                        }
                    }
                } else {
                    set e [_nthDow $y $m $ord [_dowNum $wd]]
                    if {$e ne ""} { lappend epochs $e }
                }
            }
        }
    }
    foreach d $days { lappend epochs [_mkday $y $m $d] }
    if {$epochs eq ""} {
        if {$defday <= $dim} { lappend epochs [_mkday $y $m $defday] }
    }
    return [lsort -integer -unique $epochs]
}

# Expand an RRULE. Options:
#   -dtstart ISO (required), -rule RRULE (required),
#   -from ISO, -to ISO, -count N (cap on returned occurrences).
# At least one of -to, -count, or an RRULE COUNT/UNTIL must bound the result.
# Returns a list of occurrence date(/time) strings.
proc ::tclutils::turrule::occurrences {args} {
    set opts [::tclutils::common::parseOptions \
        {-dtstart "" -rule "" -from "" -to "" -count 0} {*}$args]
    set rule [parse [dict get $opts -rule]]
    if {![dict exists $rule FREQ]} {
        return -code error -errorcode {TCLUTILS TURRULE FREQ} "RRULE has no FREQ"
    }
    set freq [string toupper [dict get $rule FREQ]]
    set interval 1
    if {[dict exists $rule INTERVAL]} { set interval [dict get $rule INTERVAL] }
    set rcount 0
    if {[dict exists $rule COUNT]} { set rcount [dict get $rule COUNT] }
    set until ""
    if {[dict exists $rule UNTIL]} { set until [_scan [dict get $rule UNTIL]] }

    set dt [_scan [dict get $opts -dtstart]]
    set dateOnly [_isDateOnly [dict get $opts -dtstart]]
    set climit [dict get $opts -count]
    set fromE [expr {[dict get $opts -from] ne "" ? [_scan [dict get $opts -from]] : $dt}]
    set toE ""
    if {[dict get $opts -to] ne ""} { set toE [_scan [dict get $opts -to]] }
    if {$toE eq "" && $rcount == 0 && $until eq "" && $climit == 0} {
        return -code error -errorcode {TCLUTILS TURRULE UNBOUNDED} \
            "unbounded expansion: supply -to, -count, COUNT or UNTIL"
    }

    set secs [expr {$dt - [_midnight $dt]}]
    lassign [clock format $dt -format {%Y %m %d} -gmt 1] sy sm sd
    scan $sy %d sy; scan $sm %d sm; scan $sd %d sd
    set weekStart [expr {[_midnight $dt] - ([_dow $dt] - 1) * 86400}]

    set out {}; set occN 0; set done 0
    for {set p 0} {!$done && $p < 200000} {incr p} {
        # period start epoch (for the toE cutoff) and candidate occurrences
        switch -- $freq {
            DAILY {
                set base [expr {$dt + $p * $interval * 86400}]
                set periodStart $base
                set cands {}
                if {![dict exists $rule BYDAY] ||
                    [_dow $base] in [lmap c [_list [dict get $rule BYDAY]] {_dowNum $c}]} {
                    lappend cands $base
                }
            }
            WEEKLY {
                set ws [expr {$weekStart + $p * $interval * 7 * 86400}]
                set periodStart $ws
                set wds {}
                if {[dict exists $rule BYDAY]} {
                    foreach c [_list [dict get $rule BYDAY]] { lappend wds [_dowNum $c] }
                } else {
                    set wds [_dow $dt]
                }
                set cands {}
                foreach wd [lsort -integer $wds] {
                    lappend cands [expr {$ws + ($wd - 1) * 86400 + $secs}]
                }
                set cands [lsort -integer $cands]
                # re-add secs already included; recompute cleanly below
            }
            MONTHLY {
                set tot [expr {($sm - 1) + $p * $interval}]
                set y [expr {$sy + $tot / 12}]
                set m [expr {$tot % 12 + 1}]
                set periodStart [_mkday $y $m 1]
                set cands {}
                foreach mid [_monthCandidates $y $m $rule $sd] {
                    lappend cands [expr {$mid + $secs}]
                }
            }
            YEARLY {
                set y [expr {$sy + $p * $interval}]
                set periodStart [_mkday $y 1 1]
                set cands {}
                if {$sd <= [_daysInMonth $y $sm]} {
                    lappend cands [expr {[_mkday $y $sm $sd] + $secs}]
                }
            }
            default {
                return -code error -errorcode {TCLUTILS TURRULE FREQ} \
                    "unsupported FREQ: \"$freq\""
            }
        }
        if {$toE ne "" && $periodStart > [expr {$toE + 86400}]} break
        foreach occ [lsort -integer $cands] {
            if {$occ < $dt} continue
            incr occN
            if {$rcount > 0 && $occN > $rcount} { set done 1; break }
            if {$until ne "" && $occ > $until} { set done 1; break }
            if {$toE ne "" && $occ > $toE} { set done 1; break }
            if {$occ >= $fromE} {
                lappend out [_fmt $occ $dateOnly]
                if {$climit > 0 && [llength $out] >= $climit} { set done 1; break }
            }
        }
    }
    return $out
}

# --- iCalendar integration ----------------------------------------------

# Expand all VEVENTs in an iCalendar document to occurrences within [from,to].
# Returns a list of dicts: {uid summary start}. Requires tclutils::tuical.
proc ::tclutils::turrule::eventsInRange {ics fromIso toIso} {
    package require tclutils::tuical 0.1
    set comps [::tclutils::tuical::parse $ics]
    set out {}
    foreach ev [::tclutils::tuical::events $comps] {
        set dtstart [::tclutils::tuical::property $ev DTSTART]
        if {$dtstart eq ""} continue
        set uid [::tclutils::tuical::property $ev UID]
        set summary [::tclutils::tuical::property $ev SUMMARY]
        set rrule [::tclutils::tuical::property $ev RRULE]
        if {$rrule eq ""} {
            set start $dtstart
            if {[catch {_scan $dtstart} e]} continue
            if {$e >= [_scan $fromIso] && $e <= [_scan $toIso]} {
                lappend out [dict create uid $uid summary $summary \
                    start [_fmt $e [_isDateOnly $dtstart]]]
            }
        } else {
            foreach occ [occurrences -dtstart $dtstart -rule $rrule \
                    -from $fromIso -to $toIso] {
                lappend out [dict create uid $uid summary $summary start $occ]
            }
        }
    }
    return $out
}

package provide tclutils::turrule 0.1
