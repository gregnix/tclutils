source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuodf
set out [file normalize [file join $::tclutils_example_dir demo-tuodf.odt]]
::tclutils::tuodf::createText $out {{Hello ODF} {Created by tclutils::tuodf}} -title Demo
puts "wrote $out"
puts [::tclutils::tuodf::text $out]
file delete -force $out
