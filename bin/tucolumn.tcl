#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tucolumn 0.1
proc usage {} { puts stderr "usage: tucolumn ?table|fill? ?-separator S? ?-output S? ?-right 0|1? ?-width N? ?-gap N? ?file?"; exit 2 }
set mode table; set opts {}; set files {}
set args $argv
if {[llength $args] && [lindex $args 0] in {table fill}} {
    set mode [lindex $args 0]; set args [lrange $args 1 end]
}
set i 0
while {$i < [llength $args]} {
    set a [lindex $args $i]
    if {$a in {-separator -output -right -width -gap}} {
        incr i; if {$i >= [llength $args]} usage
        lappend opts $a [lindex $args $i]
    } elseif {[string match -* $a]} { usage } else { lappend files $a }
    incr i
}
if {[llength $files]} {
    set s [::tclutils::tucolumn::file [lindex $files 0] -mode $mode {*}$opts]
} elseif {$mode eq "fill"} {
    set s [::tclutils::tucolumn::fill [regexp -all -inline {\S+} [read stdin]] {*}$opts]
} else {
    set s [::tclutils::tucolumn::table [read stdin] {*}$opts]
}
puts -nonewline $s; if {$s ne "" && [string index $s end] ne "\n"} { puts "" }
