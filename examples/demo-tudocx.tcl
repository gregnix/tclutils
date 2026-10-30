source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tudocx
set out [file normalize [file join $::tclutils_example_dir demo-tudocx.docx]]
::tclutils::tudocx::createText $out {{Hello DOCX} {Created by tclutils::tudocx}} -title Demo
puts "wrote $out"
puts [::tclutils::tudocx::text $out]
file delete -force $out
