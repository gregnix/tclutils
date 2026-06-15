#!/usr/bin/env tclsh
# ===========================================================================
# Demo: tclutils::tunum -- parse and sum human-formatted numbers.
# Pure Tcl, no Tk required.
# ===========================================================================

set here  [file dirname [file normalize [info script]]]
set tmDir [file normalize [file join $here .. lib tm]]
tcl::tm::path add $tmDir

package require tclutils::tunum

proc demo {expr} {
    puts [format "  %-40s= %s" $expr [uplevel 1 $expr]]
}

puts "parse -- single values:"
demo {::tclutils::tunum::parse "1.234,56"}
demo {::tclutils::tunum::parse "1,234.56"}
demo {::tclutils::tunum::parse "1234.56"}
demo {::tclutils::tunum::parse "12 \u20AC"}
demo {::tclutils::tunum::parse "-5,5"}
demo {::tclutils::tunum::parse "abc"}
demo {::tclutils::tunum::parse "abc" -default 0}

puts "\nsum -- lists (unparsable entries skipped):"
demo {::tclutils::tunum::sum {1,50 2,00 4,20}}
demo {::tclutils::tunum::sum {1.000,00 250,50}}
demo {::tclutils::tunum::sum {10 abc 5}}
demo {format "%.2f" [::tclutils::tunum::sum {1,50 2,00 4,20}]}

puts "\nisNumber:"
demo {::tclutils::tunum::isNumber "3,14"}
demo {::tclutils::tunum::isNumber "x"}
