#!/usr/bin/env tclsh
source [file join [file dirname [file normalize [info script]]] _bootstrap.tcl]
package require tclutils::tucal 0.1

proc usage {} {
    puts stderr "usage: tucal ?month? ?year?"
    puts stderr "       tucal -y year          (full year, like cal -y)"
    puts stderr "       tucal -3 ?month? ?year? (three months, like cal -3)"
    puts stderr "       tucal -w ?month? ?year?   (ISO week numbers, like cal -w)"
    puts stderr "options: -mondayfirst 0|1  -weeknumbers 0|1  -iso 0|1  -locale name"
    exit 2
}

set args $argv
set optArgs {}
set positional {}
set i 0
while {$i < [llength $args]} {
    set a [lindex $args $i]
    if {$a in {-mondayfirst -weeknumbers -iso -locale}} {
        lappend optArgs $a
        incr i
        if {$i >= [llength $args]} usage
        lappend optArgs [lindex $args $i]
    } elseif {$a eq "-w"} {
        lappend optArgs -iso 1
    } elseif {$a eq "-y"} {
        incr i
        if {$i >= [llength $args]} usage
        puts [::tclutils::tucal::year [lindex $args $i] {*}$optArgs]
        exit 0
    } elseif {$a eq "-3"} {
        incr i
        set rest [lrange $args $i end]
        puts [::tclutils::tucal::three {*}$rest {*}$optArgs]
        exit 0
    } elseif {[string match -* $a]} {
        usage
    } else {
        lappend positional $a
    }
    incr i
}

if {[llength $positional] == 0} {
    puts [::tclutils::tucal::now {*}$optArgs]
} else {
    puts [::tclutils::tucal::month {*}$positional {*}$optArgs]
}
