source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuxlsx
set out [file normalize [file join $::tclutils_example_dir demo-tuxlsx.xlsx]]
::tclutils::tuxlsx::writeRows $out {{Item Count} {Printer 3} {Router 1}} -sheet Devices
puts "wrote $out"
puts [::tclutils::tuxlsx::sheets $out]
foreach row [::tclutils::tuxlsx::rows $out] { puts [join $row \t] }
file delete -force $out
