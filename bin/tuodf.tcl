#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tuodf 0.1
proc usage {} {
    puts stderr "usage: tuodf text  file.odt            (print the document text)"
    puts stderr "       tuodf parts file.odt            (list container members)"
    puts stderr "       tuodf create out.odt ?-title T?  (paragraphs from stdin, one per line)"
    exit 2
}
if {[llength $argv] < 2} usage
set cmd [lindex $argv 0]
switch -- $cmd {
    text {
        puts [::tclutils::tuodf::text [lindex $argv 1]]
    }
    parts {
        foreach m [::tclutils::tuodf::parts [lindex $argv 1]] { puts $m }
    }
    create {
        set out [lindex $argv 1]
        set opts [lrange $argv 2 end]
        set paragraphs {}
        while {[gets stdin line] >= 0} { lappend paragraphs $line }
        ::tclutils::tuodf::createText $out $paragraphs {*}$opts
        puts stderr "wrote $out"
    }
    default usage
}
