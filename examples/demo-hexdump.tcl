source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuhexdump

puts [::tclutils::tuhexdump::file [file join $root README.md] -length 128]
