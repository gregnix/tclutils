#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tutac 0.1
if {[llength $argv]} {
    set s [::tclutils::tutac::file [lindex $argv 0]]
} else {
    set s [::tclutils::tutac::text [read stdin]]
}
puts -nonewline $s; if {$s ne "" && [string index $s end] ne "\n"} { puts "" }
