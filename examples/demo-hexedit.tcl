source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuhexedit
package require tclutils::tubin

set f [file join [pwd] demo-hexedit.bin]
set ch [open $f wb]
fconfigure $ch -translation binary -encoding iso8859-1
puts -nonewline $ch "ABCD content.xml EFG PK\x03\x04 END"
close $ch

puts "content.xml at: [::tclutils::tuhexedit::findString $f content.xml]"
puts "PK header at:   [::tclutils::tuhexedit::findHex $f {50 4B 03 04}]"
puts [::tclutils::tuhexedit::dump $f -width 8 -length 24]

file delete -force $f $f.bak
