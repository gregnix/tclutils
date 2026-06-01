#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tuuniq 0.1
proc usage {} { puts stderr "usage: tuuniq ?-count 0|1? file"; exit 2 }
set count 0
set args $argv
if {[llength $args] >= 2 && [lindex $args 0] eq "-count"} { set count [lindex $args 1]; set args [lrange $args 2 end] }
if {[llength $args] != 1} usage
if {$count} {
    foreach {line n} [::tclutils::tuuniq::countFile [lindex $args 0]] { puts "$n $line" }
} else {
    foreach line [::tclutils::tuuniq::file [lindex $args 0]] { puts $line }
}
