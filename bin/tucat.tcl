#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tucat 0.1
proc usage {} { puts stderr "usage: tucat ?-number 0|1? file ?file ...?"; exit 2 }
set opts {}
set files {}
set i 0
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    if {$a eq "-number" || $a eq "-nonblank"} {
        incr i; if {$i >= [llength $argv]} usage
        lappend opts $a [lindex $argv $i]
    } else { lappend files $a }
    incr i
}
if {[llength $files] == 0} usage
puts -nonewline [::tclutils::tucat::files $files {*}$opts]
