#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tutail 0.1
proc usage {} { puts stderr "usage: tutail ?-n count? file"; exit 2 }
set count 10
set args $argv
if {[llength $args] >= 2 && [lindex $args 0] eq "-n"} { set count [lindex $args 1]; set args [lrange $args 2 end] }
if {[llength $args] != 1} usage
puts [::tclutils::tutail::file [lindex $args 0] $count]
