source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::turegistry
set reg [::tclutils::turegistry::create]
::tclutils::turegistry::put $reg config.debug 1
::tclutils::turegistry::put $reg config.name  "addressbook"
puts "name    = [::tclutils::turegistry::get $reg config.name]"
puts "missing = [::tclutils::turegistry::get $reg config.theme dark]   (default)"
puts "keys    = [::tclutils::turegistry::keys $reg config.*]"
