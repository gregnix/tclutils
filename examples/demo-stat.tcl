source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tustat
puts [::tclutils::tustat::render [::tclutils::tustat::file [file join [file dirname [info script]] demo-stat.tcl]]]
