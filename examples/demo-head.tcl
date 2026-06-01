source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuhead
puts [::tclutils::tuhead::file [file join $root README.md] 10]
