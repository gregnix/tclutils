#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tucmp
if {[llength $argv] != 2} {
    puts stderr "usage: tucmp file1 file2"
    exit 2
}
lassign $argv a b
set r [::tclutils::tucmp::files $a $b]
if {[dict get $r equal]} {
    puts "equal"
    exit 0
}
puts $r
exit 1
