source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuevent
set bus [::tclutils::tuevent::create]
::tclutils::tuevent::subscribe $bus contact.saved {apply {{id} {puts "logger: contact $id saved"}}}
::tclutils::tuevent::subscribe $bus contact.saved {apply {{id} {puts "ui: refresh row $id"}}}
puts "handlers: [llength [::tclutils::tuevent::handlers $bus contact.saved]]"
set n [::tclutils::tuevent::emit $bus contact.saved 7]
puts "emitted to $n handlers"
::tclutils::tuevent::destroy $bus
