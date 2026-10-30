#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tudocx 0.1
proc usage {} {
    puts stderr "usage: tudocx text  file.docx            (print the document text)"
    puts stderr "       tudocx parts file.docx            (list container members)"
    puts stderr "       tudocx create out.docx ?-title T?  (paragraphs from stdin, one per line)"
    exit 2
}
if {[llength $argv] < 2} usage
fconfigure stdout -encoding utf-8
switch -- [lindex $argv 0] {
    text  { puts [::tclutils::tudocx::text [lindex $argv 1]] }
    parts { foreach m [::tclutils::tudocx::parts [lindex $argv 1]] { puts $m } }
    create {
        fconfigure stdin -encoding utf-8
        set paragraphs {}
        while {[gets stdin line] >= 0} { lappend paragraphs $line }
        ::tclutils::tudocx::createText [lindex $argv 1] $paragraphs {*}[lrange $argv 2 end]
        puts stderr "wrote [lindex $argv 1]"
    }
    default usage
}
