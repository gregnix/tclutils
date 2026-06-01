#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tufile 0.1
proc usage {} {
    puts stderr "usage: tufile ?-sigs listfile? ?cmd? file ?file ...?"
    puts stderr "  cmd: describe (default) | type | mime | check | list"
    puts stderr "  -sigs listfile   load extra signatures (repeatable)"
    exit 2
}
set cmd describe
set files {}
set i 0
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    switch -- $a {
        -sigs {
            incr i; if {$i >= [llength $argv]} usage
            ::tclutils::tufile::loadFile [lindex $argv $i]
        }
        describe - type - mime - check - list { set cmd $a }
        default { lappend files $a }
    }
    incr i
}
if {$cmd eq "list"} {
    foreach s [::tclutils::tufile::signatures] { puts $s }
    exit 0
}
if {[llength $files] == 0} usage
foreach f $files {
    switch -- $cmd {
        describe { puts "$f: [::tclutils::tufile::describe $f]" }
        type     { puts "$f: [::tclutils::tufile::type $f]" }
        mime     { puts "$f: [::tclutils::tufile::mime $f]" }
        check    {
            set c [::tclutils::tufile::checkExtension $f]
            puts "$f: [dict get $c status] (detected [dict get $c detected], ext [dict get $c declared], expected [dict get $c expected])"
        }
    }
}
