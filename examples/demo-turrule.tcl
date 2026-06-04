source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::turrule
puts "Weekly TU/TH, 4 times from 2025-10-01:"
foreach d [::tclutils::turrule::occurrences -dtstart 2025-10-01 \
        -rule "FREQ=WEEKLY;BYDAY=TU,TH;COUNT=4" -from 2025-01-01 -to 2025-12-31] {
    puts "  $d"
}
puts "First Monday each month, 3 times:"
foreach d [::tclutils::turrule::occurrences -dtstart 2025-01-01 \
        -rule "FREQ=MONTHLY;BYDAY=1MO;COUNT=3" -from 2025-01-01 -to 2025-12-31] {
    puts "  $d"
}
set ics "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:1\r\nDTSTART:20251001T090000Z\r\nSUMMARY:Standup\r\nRRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=3\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
puts "eventsInRange:"
foreach e [::tclutils::turrule::eventsInRange $ics 2025-01-01 2025-12-31] {
    puts "  [dict get $e start]  [dict get $e summary]"
}
