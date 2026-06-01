source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tucrc
set c [::tclutils::tucrc::crc32 {hello tclutils}]
puts [::tclutils::tucrc::hex32 $c]
