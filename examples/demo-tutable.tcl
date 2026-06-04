set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tutable
set headers {Module Tests Style}
set rows {{tustr 11 helper} {tulist 12 helper} {tutable 6 helper}}
puts "--- markdown ---"
puts [::tclutils::tutable::render $headers $rows -align {l r l}]
puts "\n--- box ---"
puts [::tclutils::tutable::render $headers $rows -align {l r l} -style box]
