source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tudiff
package require tclutils::tupatch

set old "alpha\nbeta\ngamma\n"
set new "alpha\nBETA\ngamma\ndelta\n"

set patch [::tclutils::tudiff::unifiedText $old $new]
puts "PATCH:"
puts $patch
puts "RESULT:"
puts [::tclutils::tupatch::text $old $patch]
