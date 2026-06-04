source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuholiday
puts "Easter 2025: [::tclutils::tuholiday::easter 2025]"
puts "German public holidays 2025:"
dict for {date name} [::tclutils::tuholiday::holidays 2025] {
    puts [format "  %s  %s" $date $name]
}
puts "Is 2025-05-01 a holiday? [::tclutils::tuholiday::isHoliday 2025-05-01]"
