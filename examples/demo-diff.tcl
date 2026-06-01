source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tudiff

set old "alpha\nbeta\ngamma\n"
set new "alpha\nBETA\ngamma\ndelta\n"

puts [::tclutils::tudiff::unifiedText $old $new -fromlabel old.txt -tolabel new.txt]
