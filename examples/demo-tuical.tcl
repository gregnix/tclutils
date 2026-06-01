source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuical
set ics "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nSUMMARY:Standup\r\nDTSTART:20260601T090000\r\nLOCATION:Online\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nSUMMARY:Release review\r\nDTSTART:20260601T140000\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
set cal [::tclutils::tuical::parse $ics]
set events [::tclutils::tuical::events $cal]
puts "Events: [llength $events]"
foreach ev $events {
    puts [format "  %-16s %s %s" \
        [::tclutils::tuical::property $ev SUMMARY] \
        [::tclutils::tuical::property $ev DTSTART] \
        [::tclutils::tuical::property $ev LOCATION]]
}
