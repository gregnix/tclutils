#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tunl 0.1
proc usage {} {
    puts stderr "usage: tunl ?-style all|nonempty|none? ?-start N? ?-increment N? ?-width N? ?-separator S? ?file?"
    exit 2
}
proc emit {s} { puts -nonewline $s; if {$s ne "" && [string index $s end] ne "\n"} { puts "" } }
set opts {}; set files {}; set i 0
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    if {$a in {-style -start -increment -width -separator}} {
        incr i; if {$i >= [llength $argv]} usage
        lappend opts $a [lindex $argv $i]
    } elseif {[string match -* $a]} { usage } else { lappend files $a }
    incr i
}
if {[llength $files]} {
    emit [::tclutils::tunl::file [lindex $files 0] {*}$opts]
} else {
    emit [::tclutils::tunl::text [read stdin] {*}$opts]
}
