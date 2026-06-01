source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuuniq

puts [::tclutils::tuuniq::uniqList {a a b a}]
puts [::tclutils::tuuniq::adjacentCount {a a b a}]
