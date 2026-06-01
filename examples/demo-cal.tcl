source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tucal
puts [::tclutils::tucal::month 5 2026]
puts ""
puts "ISO week numbers (cal -w style):"
puts [::tclutils::tucal::month 5 2026 -iso 1]
puts ""
puts "German locale (if available on this system):"
if {![catch {::tclutils::tucal::month 5 2026 -locale de_DE -iso 1} de]} {
    puts $de
} else {
    puts "(de_DE not available: $de)"
}
