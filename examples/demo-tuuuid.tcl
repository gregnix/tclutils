source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuuuid
set u [::tclutils::tuuuid::generate]
puts "v4: $u  (valid=[::tclutils::tuuuid::validate $u], version=[::tclutils::tuuuid::version $u])"
set u7 [::tclutils::tuuuid::generate -version 7]
puts "v7: $u7  (version=[::tclutils::tuuuid::version $u7])"
puts "nil: [::tclutils::tuuuid::nil]"
