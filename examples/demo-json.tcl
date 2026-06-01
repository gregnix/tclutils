source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tujson

set json {{"name":"Tcl","items":[1,2,3]}}
puts "Pretty:"
puts [::tclutils::tujson::pretty $json]
puts "Parsed name: [dict get [::tclutils::tujson::parse $json] name]"
