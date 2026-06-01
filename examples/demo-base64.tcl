source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tubase64
set enc [::tclutils::tubase64::encode {hello tclutils}]
puts $enc
puts [::tclutils::tubase64::decode $enc]
