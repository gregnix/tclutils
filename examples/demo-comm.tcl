source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tucomm

set a {apple banana pear}
set b {banana cherry pear}
set r [::tclutils::tucomm::compareLines $a $b]
puts "onlyA: [dict get $r onlyA]"
puts "onlyB: [dict get $r onlyB]"
puts "both:  [dict get $r both]"
puts "columns:\n[::tclutils::tucomm::formatColumns $r]"
