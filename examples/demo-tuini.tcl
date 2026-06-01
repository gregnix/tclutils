source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuini
set ini "app = demo\n\[server\]\nhost = localhost\nport = 8080\n\[db\]\nname = test\n"
set data [::tclutils::tuini::parse $ini]
puts "Sections: [::tclutils::tuini::sections $data]"
puts "server.host = [::tclutils::tuini::get $data server host]"
puts "server keys: [::tclutils::tuini::keys $data server]"
set data [::tclutils::tuini::setValue $data server timeout 30]
puts "--- toIni ---"
puts [::tclutils::tuini::toIni $data]
