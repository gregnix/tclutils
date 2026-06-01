source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tucode
puts "=== ASCII compact (0-127) ==="
puts [::tclutils::tucode::ascii -compact 1]
puts ""
puts "=== Arrows ==="
puts [::tclutils::tucode::signs arrows]
puts ""
puts "=== Box drawing ==="
puts [::tclutils::tucode::signs boxdraw]
