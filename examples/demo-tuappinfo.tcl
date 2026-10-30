#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tuappinfo

# track the module file itself: "package ifneeded" of a .tm ends with its path
set pkg tclutils::tuappinfo
::tclutils::tuappinfo::trackTm [lindex [package ifneeded $pkg [package provide $pkg]] end]
puts [::tclutils::tuappinfo::buildReport -title "demo-tuappinfo"]
