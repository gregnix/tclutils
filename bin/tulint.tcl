#!/usr/bin/env tclsh
# tulint -- static checks for Tcl sources (tclutils::tulint).
# Exit code: 0 no error finding, 1 at least one, 2 wrong call. --severity
# only filters what is printed; the exit code always counts every error.
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tulint 0.1
set usage "usage: tulint ?--rules {ENC-2 TST-3 ...}? ?--exclude pattern? ?--severity error|warning|info? ?--json? ?--list? path ?path ...?"
set json 0; set list 0; set show {error warning info}; set opts {}; set paths {}
for {set i 0} {$i < [llength $argv]} {incr i} {
    set a [lindex $argv $i]
    switch -- $a {
        --json     { set json 1 }
        --list     { set list 1 }
        --rules    { lappend opts -rules [lindex $argv [incr i]] }
        --exclude  { lappend excl [lindex $argv [incr i]] }
        --severity {
            set s [lindex $argv [incr i]]
            switch -- $s {
                error   { set show {error} }
                warning { set show {error warning} }
                info    { set show {error warning info} }
                default { puts stderr $usage; exit 2 }
            }
        }
        default {
            if {[string match -* $a]} { puts stderr $usage; exit 2 }
            lappend paths $a
        }
    }
}
if {[info exists excl]} { lappend opts -exclude $excl }
if {$list} {
    foreach r [::tclutils::tulint::rules] {
        puts [format "%-6s %-8s %s" [dict get $r name] [dict get $r severity] [dict get $r description]]
    }
    exit 0
}
if {![llength $paths]} { puts stderr $usage; exit 2 }
if {[catch {::tclutils::tulint::check $paths {*}$opts} found]} {
    puts stderr $found
    exit 2
}
set shown {}
foreach f $found {
    if {[dict get $f severity] in $show} { lappend shown $f }
}
if {$json} {
    puts [::tclutils::tulint::format $shown -format json]
} elseif {[llength $shown]} {
    puts [::tclutils::tulint::format $shown]
}
set sum [::tclutils::tulint::summary $found]
if {!$json} {
    puts stderr "tulint: [dict get $sum error] error, [dict get $sum warning] warning, [dict get $sum info] info"
}
exit [expr {[dict get $sum error] > 0}]
