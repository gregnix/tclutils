#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tupr 0.1
set opts {}; set files {}; set i 0
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    if {$a in {-length -header -width -number -date}} {
        incr i; if {$i >= [llength $argv]} { puts stderr "usage: tupr ?-length N? ?-header S? ?-width N? ?-number 0|1? ?-date S? ?file?"; exit 2 }
        lappend opts $a [lindex $argv $i]
    } else { lappend files $a }
    incr i
}
if {[llength $files]} {
    set s [::tclutils::tupr::file [lindex $files 0] {*}$opts]
} else {
    set s [::tclutils::tupr::text [read stdin] {*}$opts]
}
puts -nonewline $s; if {$s ne "" && [string index $s end] ne "\n"} { puts "" }
