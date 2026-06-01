#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tusort 0.1
proc usage {} { puts stderr "usage: tusort ?options? file"; exit 2 }
if {[llength $argv] < 1} usage
set file [lindex $argv end]
set opts [lrange $argv 0 end-1]
puts [::tclutils::tusort::file $file {*}$opts]
