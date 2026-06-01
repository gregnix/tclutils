source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuod

puts [::tclutils::tuod::data "Hello" -format hex]
