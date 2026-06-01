source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tucsv

set csv "name;city;note\nAlice;Berlin;\"likes Tcl; Tk\"\nBob;Vreden;OK\n"
set rows [::tclutils::tucsv::parse $csv -delimiter {;}]
puts "Rows:"
puts $rows

puts "Dict rows:"
puts [::tclutils::tucsv::dicts $rows]

puts "CSV again:"
puts [::tclutils::tucsv::text $rows -delimiter {;}]
