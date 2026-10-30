#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tuxlsx 0.1
proc usage {} {
    puts stderr "usage: tuxlsx sheets file.xlsx                  (sheet names)"
    puts stderr "       tuxlsx rows   file.xlsx ?sheet?          (cells, tab-separated)"
    puts stderr "       tuxlsx text   file.xlsx                  (all sheets)"
    puts stderr "       tuxlsx create out.xlsx ?-sheet NAME?     (rows from stdin, tab-separated)"
    exit 2
}
if {[llength $argv] < 2} usage
fconfigure stdout -encoding utf-8
lassign $argv cmd file
switch -- $cmd {
    sheets { foreach s [::tclutils::tuxlsx::sheets $file] { puts $s } }
    rows {
        set opts [expr {[llength $argv] > 2 ? [list -sheet [lindex $argv 2]] : {}}]
        foreach r [::tclutils::tuxlsx::rows $file {*}$opts] { puts [join $r \t] }
    }
    text { puts [::tclutils::tuxlsx::text $file] }
    create {
        fconfigure stdin -encoding utf-8
        set rows {}
        while {[gets stdin line] >= 0} { lappend rows [split $line \t] }
        ::tclutils::tuxlsx::writeRows $file $rows {*}[lrange $argv 2 end]
        puts stderr "wrote $file"
    }
    default usage
}
