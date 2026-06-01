source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuzip

set zipfile [file join $root examples demo.zip]
set files [list [file join $root README.md] [file join $root CHANGELOG.md]]
::tclutils::tuzip::create $zipfile $files -base $root
puts "ZIP: $zipfile"
puts "Members:"
foreach name [::tclutils::tuzip::names $zipfile] {
    puts "  $name"
}
puts "First bytes of README.md:"
puts [string range [::tclutils::tuzip::readMember $zipfile README.md] 0 80]
