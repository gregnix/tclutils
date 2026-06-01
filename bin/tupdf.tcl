#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tupdf 0.1
proc usage {} {
    puts stderr "usage: tupdf summary  file.pdf"
    puts stderr "       tupdf version  file.pdf"
    puts stderr "       tupdf objects  file.pdf"
    puts stderr "       tupdf object   file.pdf N"
    puts stderr "       tupdf trailer  file.pdf"
    puts stderr "       tupdf metadata file.pdf"
    puts stderr "       tupdf zugferd  file.pdf"
    exit 2
}
if {[llength $argv] < 2} usage
set cmd [lindex $argv 0]
set file [lindex $argv 1]
switch -- $cmd {
    version  { puts [::tclutils::tupdf::version $file] }
    trailer  { puts [::tclutils::tupdf::trailer $file] }
    objects  { foreach id [::tclutils::tupdf::objects $file] { puts $id } }
    object   {
        if {[llength $argv] < 3} usage
        puts [::tclutils::tupdf::object $file [lindex $argv 2]]
    }
    summary - metadata - zugferd {
        set d [::tclutils::tupdf::$cmd $file]
        dict for {k v} $d { puts "$k: $v" }
    }
    default usage
}
