source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tutr
puts [::tclutils::tutr::translate abc xyz {abc cab}]
puts [::tclutils::tutr::delete {a1b2c3} 0-9]
