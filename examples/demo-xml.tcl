source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuxml

puts [::tclutils::tuxml::declaration]
puts [::tclutils::tuxml::textElement title [dict create lang de] {A < B & C}]
