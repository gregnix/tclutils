source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tufind

puts "Tcl files below repo:"
foreach f [::tclutils::tufind::files $root *.tcl] {
    puts $f
}
