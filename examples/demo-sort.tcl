source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tusort

puts [::tclutils::tusort::sortList {banana apple cherry}]
puts [::tclutils::tusort::sortList {10 2 1} -numeric 1]
