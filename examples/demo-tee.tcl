source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tutee

set a [file join $root demo-tee-a.txt]
set b [file join $root demo-tee-b.txt]
::tclutils::tutee::write "hello from tutee" [list $a $b]
puts "wrote $a and $b"
