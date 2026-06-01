#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tuseq 0.1
if {[llength $argv] < 1} {
    puts stderr "usage: tuseq ?-format F? ?-separator S? ?-equalwidth 0|1? LAST | FIRST LAST | FIRST INCR LAST"
    exit 2
}
set s [::tclutils::tuseq::text {*}$argv]
puts -nonewline $s; if {$s ne "" && [string index $s end] ne "\n"} { puts "" }
