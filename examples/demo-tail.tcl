source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tutail
puts [::tclutils::tutail::file [file join $root README.md] 10]
