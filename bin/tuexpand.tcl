#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tuexpand 0.1
proc usage {} { puts stderr "usage: tuexpand ?expand|unexpand? ?-tabs N? ?-all 0|1? ?file?"; exit 2 }
set mode expand; set opts {}; set files {}
set args $argv
if {[llength $args] && [lindex $args 0] in {expand unexpand}} {
    set mode [lindex $args 0]; set args [lrange $args 1 end]
}
set i 0
while {$i < [llength $args]} {
    set a [lindex $args $i]
    if {$a in {-tabs -all}} {
        incr i; if {$i >= [llength $args]} usage
        lappend opts $a [lindex $args $i]
    } elseif {[string match -* $a]} { usage } else { lappend files $a }
    incr i
}
if {[llength $files]} {
    set fh [open [lindex $files 0] r]; set data [read $fh]; close $fh
} else { set data [read stdin] }
set s [::tclutils::tuexpand::$mode $data {*}$opts]
puts -nonewline $s; if {$s ne "" && [string index $s end] ne "\n"} { puts "" }
