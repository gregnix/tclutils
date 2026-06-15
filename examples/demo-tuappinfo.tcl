#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tuappinfo

::tclutils::tuappinfo::trackTm [info script]
puts [::tclutils::tuappinfo::buildReport -title "demo-tuappinfo"]
