#!/usr/bin/env tclsh
# Thin CLI for tclutils::tutablepng: read delimited rows from a file or stdin
# and render them as a PNG table.  See tutablepng(n) for the library API.
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tutablepng

proc usage {} {
    puts stderr "usage: tutablepng <out.png> ?-d DELIM? ?-header 0|1? ?-align SPEC? ?file?"
    exit 2
}
if {[llength $argv] < 1} usage
set out [lindex $argv 0]
set delim "\t"
set ropts {}
set file ""
set i 1
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    switch -- $a {
        -d      { incr i; set delim [lindex $argv $i] }
        -header { incr i; lappend ropts -header [lindex $argv $i] }
        -align  { incr i; lappend ropts -align [split [lindex $argv $i]] }
        default {
            if {[string match -* $a]} usage
            set file $a
        }
    }
    incr i
}
set text [expr {$file ne "" ? [::tclutils::common::readFile $file] : [read stdin]}]
set rows {}
foreach line [split [string trimright $text \n] \n] {
    lappend rows [split $line $delim]
}
if {[llength $rows] == 0} { puts stderr "no input rows"; exit 1 }
::tclutils::tutablepng::write $out $rows {*}$ropts
puts $out
