source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tucut

puts [::tclutils::tucut::fields "id;name;city" ";" {2 3}]
