#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tusysinfo 0.1
set usage "usage: tusysinfo ?--json? ?--serials? ?--anonymize? ?--sections {os cpu ...}? ?--timeout ms?"
set json 0; set anon 0; set opts {}
for {set i 0} {$i < [llength $argv]} {incr i} {
    switch -- [lindex $argv $i] {
        --json      { set json 1 }
        --serials   { lappend opts -serials 1 }
        --anonymize { set anon 1 }
        --sections  { lappend opts -sections [lindex $argv [incr i]] }
        --timeout   { lappend opts -timeout [lindex $argv [incr i]] }
        default     { puts stderr $usage; exit 2 }
    }
}
if {[catch {::tclutils::tusysinfo::collect {*}$opts} info]} {
    puts stderr $info
    exit 1
}
if {$json} {
    if {$anon} { dict set info host "" }
    puts [::tclutils::tusysinfo::toJson $info]
} else {
    puts [::tclutils::tusysinfo::report $info -anonymize $anon]
}
