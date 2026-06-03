source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tubase32
set enc [::tclutils::tubase32::encode {hello tclutils}]
puts "base32:    $enc"
puts "decoded:   [::tclutils::tubase32::decode $enc]"
puts "base32hex: [::tclutils::tubase32::encode foobar -hex 1]"
puts "no pad:    [::tclutils::tubase32::encode foo -pad 0]"
