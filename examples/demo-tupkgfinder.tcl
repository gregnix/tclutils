#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tupkgfinder

puts "Report for package 'tcltest':\n"
puts [::tclutils::tupkgfinder::report tcltest]

set w [::tclutils::tupkgfinder::which tcltest]
puts "active version: [dict get $w activeVersion]"
puts "active path   : [dict get $w activePath]"
puts "shadowed      : [dict get $w shadowed]"
