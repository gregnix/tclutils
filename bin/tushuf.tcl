#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tushuf 0.1
set opts {}; set files {}; set i 0
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    if {$a in {-seed -count}} {
        incr i; if {$i >= [llength $argv]} { puts stderr "usage: tushuf ?-seed N? ?-count N? ?file?"; exit 2 }
        lappend opts $a [lindex $argv $i]
    } else { lappend files $a }
    incr i
}
if {[llength $files]} {
    set s [::tclutils::tushuf::file [lindex $files 0] {*}$opts]
} else {
    set s [::tclutils::tushuf::text [read stdin] {*}$opts]
}
puts -nonewline $s; if {$s ne "" && [string index $s end] ne "\n"} { puts "" }
