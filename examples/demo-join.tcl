source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tujoin

set names "1;Ada\n2;Linus\n"
set cities "1;Berlin\n2;Helsinki\n"
puts [::tclutils::tujoin::texts $names $cities -delimiter ";"]
