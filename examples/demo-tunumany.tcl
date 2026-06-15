#!/usr/bin/env tclsh
# ===========================================================================
# Demo: tclutils::tunumany -- one parse() that accepts both locale/currency
# amounts and SI/IEC unit notation, routing to the right backend.
# ===========================================================================
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tunumany

foreach s {"1.234,56" "1,234.56" "12 \u20AC" "1.5K" "2Mi" "3G" "42" "x"} {
    puts [format "%-12s -> %s" $s [::tclutils::tunumany::parse $s -default "(none)"]]
}
