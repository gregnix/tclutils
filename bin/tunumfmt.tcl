#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tunumfmt 0.1
proc usage {} { puts stderr "usage: tunumfmt ?-mode to|from? ?-to si|iec? ?-from si|iec|auto? ?-precision N? ?file?"; exit 2 }
set opts {}; set files {}; set i 0
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    if {$a in {-mode -to -from -precision}} {
        incr i; if {$i >= [llength $argv]} usage
        lappend opts $a [lindex $argv $i]
    } elseif {[string match -* $a]} { usage } else { lappend files $a }
    incr i
}
if {[llength $files]} {
    set s [::tclutils::tunumfmt::file [lindex $files 0] {*}$opts]
} else {
    set s [::tclutils::tunumfmt::text [read stdin] {*}$opts]
}
puts -nonewline $s; if {$s ne "" && [string index $s end] ne "\n"} { puts "" }
