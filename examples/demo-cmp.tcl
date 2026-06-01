source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tucmp

set root [file dirname [file dirname [file normalize [info script]]]]
set a [lindex $argv 0]
set b [lindex $argv 1]
if {$a eq ""} { set a [file join $root README.md] }
if {$b eq ""} { set b [file join $root README.md] }
puts [::tclutils::tucmp::files $a $b]
