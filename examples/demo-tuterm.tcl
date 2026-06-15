#!/usr/bin/env tclsh
# ===========================================================================
# Demo: tclutils::tuterm -- ANSI terminal styling.
# Run in a terminal that understands ANSI (on Windows call enableVT first).
# ===========================================================================
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tuterm
namespace import ::tclutils::tuterm::*

auto                 ;# respect NO_COLOR
enableVT             ;# Windows: turn on VT processing

puts [wrap "Important!"      bold fg:red]
puts [wrap "Holiday"         bold fg:yellow]
puts [wrap "note text"       italic fg:cyan]
puts [wrap "reverse video"   reverse]
puts "[style fg:green]ok[style reset]  [style fg:bright_black]dimmed[style reset]"

puts "\n256-color ramp:"
set line ""
foreach i {16 52 88 124 160 196 202 208 214 220 226} {
    append line [wrap "  " bg:$i]
}
puts $line

puts "\ntruecolor gradient:"
set line ""
for {set r 0} {$r < 256} {incr r 32} {
    append line [wrap " " bg:[format "#%02x3060" $r]]
}
puts $line

puts "\nplain (strip): [strip [wrap {styled} bold fg:red]]"
