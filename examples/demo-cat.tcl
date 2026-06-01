source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tucat
puts [::tclutils::tucat::file [file join $root README.md] -number 1]
