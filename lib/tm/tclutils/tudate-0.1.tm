# tclutils::tudate -- flexible date helpers on top of the Tcl clock command.
# Description: flexible date helpers on top of the Tcl clock command.
# Category: Date · time/calendar
# Parse common formats, render ISO, do calendar arithmetic, day differences and
# human-readable relative phrases. Works in local time. Tcl 8.6+ and 9.x.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tudate {
    namespace export parse iso add diff relative today
    variable version 0.1
    # tried in order when no -format is given (day-first for the "." and "/" forms)
    variable FORMATS {
        {%Y-%m-%dT%H:%M:%S} {%Y-%m-%d %H:%M:%S} {%Y-%m-%d}
        {%d.%m.%Y} {%d/%m/%Y} {%Y/%m/%d}
    }
}

# Parse a date/time string to epoch seconds. Option: -format fmt (otherwise a
# list of common formats is tried, then a free-form clock scan). Errors with
# {TCLUTILS TUDATE PARSE} if nothing matches.
proc ::tclutils::tudate::parse {str args} {
    variable FORMATS
    set opts [::tclutils::common::parseOptions {-format ""} {*}$args]
    set fmt [dict get $opts -format]
    if {$fmt ne ""} {
        if {[catch {clock scan $str -format $fmt} t]} {
            return -code error -errorcode {TCLUTILS TUDATE PARSE} \
                "cannot parse \"$str\" with format \"$fmt\""
        }
        return $t
    }
    foreach f $FORMATS {
        if {![catch {clock scan $str -format $f} t]} { return $t }
    }
    if {![catch {clock scan $str} t]} { return $t }
    return -code error -errorcode {TCLUTILS TUDATE PARSE} \
        "cannot parse date: \"$str\""
}

# ISO rendering of epoch seconds. Option: -time bool (default 0) for date-time.
proc ::tclutils::tudate::iso {seconds args} {
    set opts [::tclutils::common::parseOptions {-time 0} {*}$args]
    set t [::tclutils::common::ensureBoolean [dict get $opts -time] -time]
    return [clock format $seconds \
        -format [expr {$t ? "%Y-%m-%dT%H:%M:%S" : "%Y-%m-%d"}]]
}

# Calendar arithmetic: add $count of $unit to $seconds.
# unit: second(s) minute(s) hour(s) day(s) week(s) month(s) year(s).
proc ::tclutils::tudate::add {seconds count unit} {
    set u [string trimright $unit s]
    set map {second seconds minute minutes hour hours day days \
             week weeks month months year years}
    if {![dict exists $map $u]} {
        return -code error -errorcode {TCLUTILS TUDATE UNIT} \
            "unknown unit: \"$unit\""
    }
    return [clock add $seconds $count [dict get $map $u]]
}

# Integer difference (a - b) in a fixed-length unit. Option: -unit
# seconds|minutes|hours|days|weeks (default days). Result is truncated.
proc ::tclutils::tudate::diff {a b args} {
    set opts [::tclutils::common::parseOptions {-unit days} {*}$args]
    set div [dict get {seconds 1 minutes 60 hours 3600 days 86400 weeks 604800} \
        [dict get $opts -unit]]
    return [expr {($a - $b) / $div}]
}

# Human-readable relative phrase (day granularity). Option: -base seconds
# (default now).
proc ::tclutils::tudate::relative {seconds args} {
    set opts [::tclutils::common::parseOptions {-base ""} {*}$args]
    set base [dict get $opts -base]
    if {$base eq ""} { set base [clock seconds] }
    set d1 [clock scan [iso $seconds] -format %Y-%m-%d]
    set d0 [clock scan [iso $base] -format %Y-%m-%d]
    set days [expr {round(($d1 - $d0) / 86400.0)}]
    if {$days == 0}  { return "today" }
    if {$days == 1}  { return "tomorrow" }
    if {$days == -1} { return "yesterday" }
    if {$days > 1}   { return "in $days days" }
    return "[expr {-$days}] days ago"
}

# Today's date as an ISO string.
proc ::tclutils::tudate::today {} {
    return [clock format [clock seconds] -format %Y-%m-%d]
}

package provide tclutils::tudate 0.1
