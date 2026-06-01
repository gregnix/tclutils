#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tuagrep 0.1
proc usage {} { puts stderr "usage: tuagrep ?-maxdist N? ?-nocase 0|1? ?options? pattern file ?file ...?"; exit 2 }
set opts {}
set pos {}
set i 0
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    if {[string match -* $a]} {
        incr i; if {$i >= [llength $argv]} usage
        lappend opts $a [lindex $argv $i]
    } else { lappend pos $a }
    incr i
}
if {[llength $pos] < 2} usage
set pattern [lindex $pos 0]
set files [lrange $pos 1 end]
set matches [::tclutils::tuagrep::files $files $pattern {*}$opts]
foreach m $matches {
    if {[llength $m] == 2} {
        puts "[lindex $m 0]:[lindex $m 1]"
    } else {
        puts $m
    }
}
