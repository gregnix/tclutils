#!/usr/bin/env tclsh
source [file join [file dirname [file normalize [info script]]] _bootstrap.tcl]
package require tclutils::tuzipfs

proc usage {} {
    puts stderr "usage: tuzipfs.tcl available | root | mount ZIP ?NAME? | unmount MOUNT | list MOUNT ?GLOB? | read PATH"
    exit 2
}

if {$argc < 1} { usage }
set cmd [lindex $argv 0]
set args [lrange $argv 1 end]

switch -- $cmd {
    available {
        puts [::tclutils::tuzipfs::available]
    }
    root {
        puts [::tclutils::tuzipfs::root]
    }
    mount {
        if {[llength $args] < 1 || [llength $args] > 2} { usage }
        puts [::tclutils::tuzipfs::mount {*}$args]
    }
    unmount {
        if {[llength $args] != 1} { usage }
        ::tclutils::tuzipfs::unmount [lindex $args 0]
    }
    list {
        if {[llength $args] < 1 || [llength $args] > 2} { usage }
        set mount [lindex $args 0]
        set glob [expr {[llength $args] == 2 ? [lindex $args 1] : "*"}]
        foreach path [::tclutils::tuzipfs::listFiles $mount -glob $glob] { puts $path }
    }
    read {
        if {[llength $args] != 1} { usage }
        puts -nonewline [::tclutils::tuzipfs::readFile [lindex $args 0]]
    }
    default { usage }
}
