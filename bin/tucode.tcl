#!/usr/bin/env tclsh
source [file join [file dirname [file normalize [info script]]] _bootstrap.tcl]
package require tclutils::tucode 0.1

proc usage {} {
    puts stderr "usage: tucode ascii|latin1|ansi|signs|groups ?groups...?"
    puts stderr "       tucode table FROM TO ?-compact 1?"
    puts stderr "       tucode lookup CODE|CHAR"
    puts stderr "options: -compact 1   hex matrix (16 columns)"
    puts stderr "groups: controls whitespace quotes dashes german currency math latin1hi"
    puts stderr "        arrows boxdraw boxdraw2"
    exit 2
}

if {[llength $argv] < 1} usage
set cmd [lindex $argv 0]
set rest [lrange $argv 1 end]

switch -- $cmd {
    ascii  { puts [::tclutils::tucode::ascii {*}$rest] }
    latin1 - ansi { puts [::tclutils::tucode::latin1 {*}$rest] }
    signs  { puts [::tclutils::tucode::signs {*}$rest] }
    groups { puts [::tclutils::tucode::groups] }
    table {
        if {[llength $rest] < 2} usage
        set from [lindex $rest 0]
        set to [lindex $rest 1]
        set opts [lrange $rest 2 end]
        puts [::tclutils::tucode::table $from $to {*}$opts]
    }
    lookup {
        if {[llength $rest] != 1} usage
        set d [::tclutils::tucode::lookup [lindex $rest 0]]
        puts [format "%s  %s  %s  %s  %s" \
            [dict get $d code] [dict get $d hex] [dict get $d glyph] \
            [dict get $d name] [dict get $d char]]
    }
    default usage
}
