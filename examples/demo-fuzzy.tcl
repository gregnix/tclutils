source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tufuzzy
puts [::tclutils::tufuzzy::distance kitten sitting]
puts [::tclutils::tufuzzy::bestMatch colour {color flavour colorful}]
