set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tudict
set defaults {server {host localhost port 5232} log {level info}}
set user     {server {port 8080} log {level debug} extra 1}
set cfg [::tclutils::tudict::mergeDeep $defaults $user]
puts "merged:   $cfg"
puts "host:     [::tclutils::tudict::getOr $cfg ? server host]"
puts "timeout?: [::tclutils::tudict::getOr $cfg 30 server timeout]"
puts "flatten:  [::tclutils::tudict::flatten $cfg]"
puts "paths:    [::tclutils::tudict::paths $cfg]"
