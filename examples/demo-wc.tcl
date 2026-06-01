source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuwc

puts [::tclutils::tuwc::file [file join $root README.md]]
