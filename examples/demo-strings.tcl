source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tustrings

puts [::tclutils::tustrings::file [file join $root README.md] -minlength 8]
