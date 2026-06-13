#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir
package require tclutils::tupagespec

set total 12
puts "Document has $total pages.\n"
foreach spec {"" all 1-3,5 5- -4 4-last 7-5,2} {
    set pages [::tclutils::tupagespec::parse $spec $total]
    puts [format {  %-10s -> %s  (%d pages)} \
        "\"$spec\"" $pages [llength $pages]]
}

puts "\nCompacting a selection back to a spec:"
foreach sel {{1 2 3 5 7 8} {2 4 6 8 10} {5 1 2 3}} {
    puts [format {  %-18s -> %s} $sel [::tclutils::tupagespec::compact $sel]]
}

puts "\nRound-trip 1-3,5,9-11:"
set p [::tclutils::tupagespec::parse {1-3,5,9-11} 20]
puts "  parse   -> $p"
puts "  compact -> [::tclutils::tupagespec::compact $p]"
