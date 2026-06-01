#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tuwc 0.1
proc usage {} { puts stderr "usage: tuwc file ?file ...?"; exit 2 }
if {[llength $argv] == 0} usage
foreach path $argv {
    set s [::tclutils::tuwc::file $path]
    puts [format "%7d %7d %7d %7d %s" [dict get $s lines] [dict get $s words] [dict get $s chars] [dict get $s bytes] $path]
}
