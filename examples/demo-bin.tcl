source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tubin

set bytes [::tclutils::tubin::hexToBytes {50 4B 03 04}]
puts [::tclutils::tubin::bytesToHex $bytes]
puts [format %x [::tclutils::tubin::u32le [::tclutils::tubin::hexToBytes {78 56 34 12}]]]
