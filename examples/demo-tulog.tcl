source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tulog
set log [::tclutils::tulog::new -name demo -level info -channel stdout]
$log info  "this is info"
$log debug "hidden while level is info"
$log warn  "a warning"
$log setLevel debug
$log debug "now debug is visible"
$log error "and an error"
$log destroy
# assertion helper
if {[catch {::tclutils::tulog::assert {1 == 2} "1 is not 2"} err]} {
    puts "assert caught: $err"
}
