#!/usr/bin/env tclsh
# Thin CLI for tclutils::tumonthpng: render a month calendar to a PNG.
# See tumonthpng(n) for the library API (holidays/notes are library options).
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tumonthpng

proc usage {} {
    puts stderr "usage: tumonthpng <out.png> <year> <month> ?-theme default|dark|light? ?-scale N? ?-today YYYY-MM-DD? ?-showweeks 0|1?"
    exit 2
}
if {[llength $argv] < 3} usage
set out   [lindex $argv 0]
set year  [lindex $argv 1]
set month [lindex $argv 2]
set opts {}
foreach {k v} [lrange $argv 3 end] {
    if {$k ni {-theme -scale -today -showweeks}} usage
    lappend opts $k $v
}
::tclutils::tumonthpng::write $out $year $month {*}$opts
puts $out
