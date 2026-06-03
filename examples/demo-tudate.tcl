source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tudate
set t [::tclutils::tudate::parse "15.03.2024"]
puts "parsed 15.03.2024 -> ISO [::tclutils::tudate::iso $t]"
puts "  + 10 days  -> [::tclutils::tudate::iso [::tclutils::tudate::add $t 10 days]]"
puts "  + 1 year   -> [::tclutils::tudate::iso [::tclutils::tudate::add $t 1 year]]"
puts "  diff to 20.03 -> [::tclutils::tudate::diff [::tclutils::tudate::parse 2024-03-20] $t] days"
puts "  relative (+1d) -> [::tclutils::tudate::relative [::tclutils::tudate::add $t 1 day] -base $t]"
puts "today -> [::tclutils::tudate::today]"
