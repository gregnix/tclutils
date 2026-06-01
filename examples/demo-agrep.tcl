source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuagrep
set text "alpha line\nbeta line\ngamma line"
puts [::tclutils::tuagrep::search $text gama -maxdist 1]
