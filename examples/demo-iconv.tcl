source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuiconv

set bytes [encoding convertto cp1252 "äöü"]
puts [encoding convertfrom utf-8 [::tclutils::tuiconv::convert $bytes cp1252 utf-8]]
