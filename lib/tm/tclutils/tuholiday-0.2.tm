# tclutils::tuholiday -- public-holiday dates from the Easter computus.
# Description: public-holiday dates from the Easter computus.
# Category: Date · time/calendar
#
# Computes Easter Sunday (Gregorian, Meeus/Jones/Butcher algorithm) and the
# German public holidays of a year. Pure Tcl on top of clock. Tcl 8.6+ and 9.x.
#
# Region "de" yields eleven days: the nine holidays that are statutory in all
# German states plus Easter Sunday and Whit Sunday (Sundays anyway; statutory
# in a few states only). -sundays 0 gives the nine. State-specific days
# (Heilige Drei Koenige, Fronleichnam, Allerheiligen, Reformationstag, ...)
# are intentionally not in the base set.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuholiday {
    namespace export easter holidays isHoliday
    variable version 0.2
}

# Easter Sunday of $year as an ISO date (Gregorian computus).
proc ::tclutils::tuholiday::easter {year} {
    if {![string is integer -strict $year]} {
        return -code error -errorcode {TCLUTILS TUHOLIDAY YEAR} \
            "not a year: \"$year\""
    }
    set a [expr {$year % 19}]
    set b [expr {$year / 100}]
    set c [expr {$year % 100}]
    set d [expr {$b / 4}]
    set e [expr {$b % 4}]
    set f [expr {($b + 8) / 25}]
    set g [expr {($b - $f + 1) / 3}]
    set h [expr {(19*$a + $b - $d - $g + 15) % 30}]
    set i [expr {$c / 4}]
    set k [expr {$c % 4}]
    set l [expr {(32 + 2*$e + 2*$i - $h - $k) % 7}]
    set m [expr {($a + 11*$h + 22*$l) / 451}]
    set month [expr {($h + $l - 7*$m + 114) / 31}]
    set day   [expr {(($h + $l - 7*$m + 114) % 31) + 1}]
    return [format %04d-%02d-%02d $year $month $day]
}

proc ::tclutils::tuholiday::_offset {iso days} {
    set t [clock scan $iso -format %Y-%m-%d -gmt 1]
    return [clock format [clock add $t $days days -gmt 1] -format %Y-%m-%d -gmt 1]
}

# Holidays of $year as a dict {ISO-date -> name}. Options: -region (default
# de), -sundays 0|1 (default 1: with Ostersonntag and Pfingstsonntag; 0: the
# nine days statutory in all German states, as tical::holidays::de).
proc ::tclutils::tuholiday::holidays {year args} {
    set opts [::tclutils::common::parseOptions {-region de -sundays 1} {*}$args]
    set sundays [dict get $opts -sundays]
    if {![string is boolean -strict $sundays]} {
        return -code error -errorcode {TCLUTILS TUHOLIDAY SUNDAYS} \
            "-sundays must be 0 or 1, got \"$sundays\""
    }
    set region [string tolower [dict get $opts -region]]
    if {$region ne "de"} {
        return -code error -errorcode {TCLUTILS TUHOLIDAY REGION} \
            "unknown region: \"$region\""
    }
    set e [easter $year]
    set d [dict create]
    dict set d [format %04d-01-01 $year] "Neujahr"
    dict set d [_offset $e -2]  "Karfreitag"
    if {$sundays} { dict set d $e "Ostersonntag" }
    dict set d [_offset $e 1]   "Ostermontag"
    dict set d [format %04d-05-01 $year] "Tag der Arbeit"
    dict set d [_offset $e 39]  "Christi Himmelfahrt"
    if {$sundays} { dict set d [_offset $e 49] "Pfingstsonntag" }
    dict set d [_offset $e 50]  "Pfingstmontag"
    dict set d [format %04d-10-03 $year] "Tag der Deutschen Einheit"
    dict set d [format %04d-12-25 $year] "1. Weihnachtstag"
    dict set d [format %04d-12-26 $year] "2. Weihnachtstag"
    # return sorted by date
    set out [dict create]
    foreach k [lsort [dict keys $d]] { dict set out $k [dict get $d $k] }
    return $out
}

# Holiday name for an ISO date, or "" if it is not a holiday. Options as
# holidays.
proc ::tclutils::tuholiday::isHoliday {iso args} {
    set opts [::tclutils::common::parseOptions {-region de -sundays 1} {*}$args]
    set year [lindex [split $iso -] 0]
    set h [holidays $year -region [dict get $opts -region] -sundays [dict get $opts -sundays]]
    if {[dict exists $h $iso]} { return [dict get $h $iso] }
    return ""
}

package provide tclutils::tuholiday 0.2
