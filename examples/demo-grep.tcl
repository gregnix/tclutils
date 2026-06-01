source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tugrep

set readme [file join $root README.md]
foreach match [::tclutils::tugrep::file $readme Tcl -nocase 1 -linenumbers 1] {
    puts $match
}
