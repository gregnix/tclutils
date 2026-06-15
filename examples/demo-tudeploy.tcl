#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tudeploy
interp alias {} tudeploy {} ::tclutils::tudeploy
# Build a tiny app tree:  <tmp>/app/{vendor/demo/widget-1.0.tm, vendor/webp, bin}
set tmp [file join [file dirname [file tempfile]] tudeploy-demo]
file delete -force $tmp
set app [file join $tmp app]
file mkdir [file join $app vendor demo]
file mkdir [file join $app vendor webp [::tclutils::tudeploy::platformTag]]
file mkdir [file join $app bin]
set fh [open [file join $app vendor demo widget-1.0.tm] w]
puts $fh {package provide demo::widget 1.0}
close $fh

puts "platformTag : [tudeploy platformTag]"
puts "module roots: [tudeploy roots -base [list $app] -parents 0]"
puts "require demo::widget -> [tudeploy require {demo::widget} -base [list $app] -parents 0]"
puts "require missing      -> [tudeploy require {no::such} -base [list $app] -parents 0]"
puts "webp resource dirs:"
foreach d [tudeploy resourceDirs webp -base [list $app] -parents 0] { puts "  $d" }


# A package whose vendored layout doesn't match its name: qpdf-like at
# vendor/qpdf/lib/qpdf-1.0.tm (bare package "qpdf"). sourceModule loads it by
# sourcing the file in place, even when "vendor" is already a tm root.
file mkdir [file join $app vendor qpdf lib]
set fh [open [file join $app vendor qpdf lib qpdf-1.0.tm] w]
puts $fh {package provide qpdf 1.0}
close $fh
tcl::tm::path add [file join $app vendor]
puts "tm require qpdf  -> [tudeploy require {qpdf} -base [list $app] -parents 0]  (blocked by shared root)"
puts "sourceModule qpdf-> [tudeploy sourceModule qpdf -base [list $app] -parents 0 -roots {{vendor qpdf lib}}]"

file delete -force $tmp
