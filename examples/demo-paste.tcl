source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tupaste

puts [::tclutils::tupaste::texts [list "Ada\nLinus\n" "Berlin\nHelsinki\n"] -delimiter ";"]
