# tclutils::tudate -- flexible date helpers on top of the Tcl clock command.
# Description: flexible date helpers on top of the Tcl clock command.
# Category: Date · time/calendar
# Parse common formats, render ISO, do calendar arithmetic, day differences and
# human-readable relative phrases, list of time zones. Works in local time.
# Tcl 8.6+ and 9.x.
#
# parse checks every format match by formatting the result back: Tcl 8.6
# rolls 2026-02-29 over to 2026-03-01 and month 29 into a later year, Tcl 9.0
# rejects both. With the check both interpreters give the same answer.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tudate {
    namespace export parse iso add diff relative today zones
    variable version 0.3
    # tried in order when no -format is given (day-first for the "." and "/"
    # forms; month-first m/d/Y only when d/m/Y gives no valid date)
    variable FORMATS {
        {%Y-%m-%dT%H:%M:%S} {%Y-%m-%d %H:%M:%S} {%Y-%m-%d}
        {%Y-%m-%dT%H:%M} {%Y-%m-%d %H:%M} {%Y%m%dT%H%M%S} {%Y%m%d}
        {%d.%m.%Y %H:%M:%S} {%d.%m.%Y %H:%M} {%d.%m.%Y}
        {%d/%m/%Y} {%Y/%m/%d} {%m/%d/%Y} {%H:%M:%S} {%H:%M}
        {%d %b %Y} {%b %d %Y} {%b %d, %Y}
    }
}

# Scan $str with $fmt; 1 and the seconds in $tVar when it matches and the
# numbers formatted back are the numbers of the input (no rolled-over day).
proc ::tclutils::tudate::_scan {str fmt tVar} {
    upvar 1 $tVar t
    if {[catch {clock scan $str -format $fmt} t]} { return 0 }
    set in  [regexp -all -inline {[0-9]+} $str]
    set out [regexp -all -inline {[0-9]+} [clock format $t -format $fmt]]
    if {[llength $in] != [llength $out]} { return 0 }
    foreach a $in b $out {
        if {[scan $a %d] != [scan $b %d]} { return 0 }
    }
    return 1
}

# 1 unless the free-form scan rolled a named month with a day over into the
# next month ("Feb 30 2026" is March 2 on Tcl 8.6, an error on 9.0).
proc ::tclutils::tudate::_freeOk {str t} {
    set mon {jan feb mar apr may jun jul aug sep oct nov dec}
    set re1 {(?i)\m([a-z]{3})[a-z]*\.?\s+([0-9]{1,2})\M}
    set re2 {(?i)\m([0-9]{1,2})\.?\s+([a-z]{3})[a-z]*\M}
    if {[regexp $re1 $str -> m d] || [regexp $re2 $str -> d m]} {
        set i [lsearch -exact $mon [string tolower $m]]
        if {$i < 0} { return 1 }
        return [expr {[scan [clock format $t -format %m] %d] == $i + 1
                   && [scan [clock format $t -format %d] %d] == [scan $d %d]}]
    }
    return 1
}

# Parse a date/time string to epoch seconds. Option: -format fmt (otherwise a
# list of common formats is tried, then a free-form clock scan). A day or
# month that does not exist (2026-02-29, 31.04.2026) is an error, on Tcl 8.6
# as on 9.0. A string of digits and separators only never goes to the
# free-form scan. Errors with {TCLUTILS TUDATE PARSE} if nothing matches.
proc ::tclutils::tudate::parse {str args} {
    variable FORMATS
    set opts [::tclutils::common::parseOptions {-format ""} {*}$args]
    set fmt [dict get $opts -format]
    if {$fmt ne ""} {
        if {![_scan $str $fmt t]} {
            return -code error -errorcode {TCLUTILS TUDATE PARSE} \
                "cannot parse \"$str\" with format \"$fmt\""
        }
        return $t
    }
    foreach f $FORMATS {
        if {[_scan $str $f t]} { return $t }
    }
    if {![regexp {^[0-9]+([-./ :T][0-9]+)*$} [string trim $str]]
            && ![catch {clock scan $str} t] && [_freeOk $str $t]} {
        return $t
    }
    return -code error -errorcode {TCLUTILS TUDATE PARSE} \
        "cannot parse date: \"$str\""
}

# ISO rendering of epoch seconds. Option: -time bool (default 0) for date-time.
proc ::tclutils::tudate::iso {seconds args} {
    set opts [::tclutils::common::parseOptions {-time 0} {*}$args]
    set t [::tclutils::common::ensureBoolean [dict get $opts -time] -time]
    if {$t} {
        set fmt "%Y-%m-%dT%H:%M:%S"
    } else {
        set fmt "%Y-%m-%d"
    }
    return [clock format $seconds -format $fmt]
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

# Time zone names that [clock format -timezone] accepts, sorted, e.g.
# Europe/Berlin. Read from Tcl's own tzdata (also inside a zipfs image), else
# from the system zoneinfo directory. "UTC" is always included. The first
# source with entries wins, so the list does not mix two databases.
#
# Names from the system directory are checked with clock first: Tcl 8.6
# without its own tzdata (Debian/Ubuntu) rejects Etc/GMT+1 and the like
# ("time zone ... not found"). Costs about 0.3 s once; Tcl's tzdata needs
# no check.
proc ::tclutils::tudate::zones {} {
    set dirs [list [file join [info library] tzdata]]
    if {[info exists ::tcl_pkgPath]} {       ;# not set on every build
        foreach p $::tcl_pkgPath { lappend dirs [file join $p tzdata] }
    }
    set system /usr/share/zoneinfo
    lappend dirs $system
    set zones {}
    foreach base $dirs {
        if {![file isdirectory $base]} continue
        foreach z [glob -nocomplain -directory $base -tails -type f */* */*/*] {
            # Area/City; skips posix/, right/ and files like zone.tab
            if {![regexp {^[A-Z][A-Za-z_]+/[A-Za-z0-9_+/-]+$} $z]} continue
            if {$base eq $system && [catch {clock format 0 -timezone $z}]} continue
            lappend zones $z
        }
        if {[llength $zones]} break
    }
    lappend zones UTC
    return [lsort -unique $zones]
}

package provide tclutils::tudate 0.3
