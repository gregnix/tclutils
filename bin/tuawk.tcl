#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tuawk 0.1
proc usage {} {
    puts stderr "usage: tuawk ?-fs SEP? ?-ofs SEP? ?-ors SEP? rules ?file ...?"
    puts stderr {  rules is a Tcl list of pattern/action pairs, e.g.  '{} {emit $2}'}
    puts stderr {  fields: $0 $1..$NF, $NR, $NF;  emit prints;  BEGIN/END supported}
    puts stderr {  example: tuawk -fs : '{$3 > 100} {emit $1}' /etc/passwd}
    exit 2
}
set opts {}
set rules ""
set files {}
set haveRules 0
set i 0
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    switch -- $a {
        -fs - -ofs - -ors {
            incr i; if {$i >= [llength $argv]} usage
            lappend opts $a [lindex $argv $i]
        }
        default {
            if {!$haveRules} { set rules $a; set haveRules 1 } else { lappend files $a }
        }
    }
    incr i
}
if {!$haveRules} usage

if {[llength $files] == 0} {
    set text [read stdin]
} else {
    set text ""
    foreach f $files {
        set fh [open $f r]
        append text [read $fh]
        close $fh
    }
}
puts -nonewline [::tclutils::tuawk::run $text $rules {*}$opts]
