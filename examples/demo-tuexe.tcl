#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tuexe

puts "Looking up some common tools on this system:\n"
foreach spec {
    {tclsh}
    {sh}
    {python python3}
    {gs gswin64c gswin32c gsc}
    {ffmpeg}
    {qpdf}
} {
    set p [::tclutils::tuexe::find $spec]
    set shown [expr {$p eq "" ? "(not found)" : $p}]
    puts [format {  %-28s -> %s} $spec $shown]
}

puts "\nexists tclsh: [::tclutils::tuexe::exists tclsh]"
puts "all sh:      [::tclutils::tuexe::all sh]"
