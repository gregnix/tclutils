#!/usr/bin/env tclsh
# ===========================================================================
# Demo: tclutils::tucolor -- named-color database and conversions (GUI-free).
# ===========================================================================
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tucolor
namespace import ::tclutils::tucolor::*

puts "known names: [llength [names]]  (e.g. [lrange [names] 0 4] ...)"
foreach c {red cornflowerblue tomato steelblue rebeccapurple} {
    puts [format "  %-16s rgb=%-13s hex=%-8s hsv=%s" \
        $c [rgb $c] [hex $c] [toHsv $c]]
}
puts "\nhex parsing:    #f80 -> [rgb #f80]    #ff8800 -> [rgb #ff8800]"
puts "nearest names:  #fe0000 -> [nearest #fe0000]   {100 149 238} -> [nearest {100 149 238}]"
puts "hsv -> rgb:     {120 100 100} -> [fromHsv {120 100 100}] (green)"
