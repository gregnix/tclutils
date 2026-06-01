source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tused

set text "foo foo\n# comment\nkeep foo"
set rules [list [list s foo bar g] [list d {^#}]]
puts [::tclutils::tused::process $text $rules]
