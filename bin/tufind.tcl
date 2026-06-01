#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tufind 0.1
proc usage {} { puts stderr "usage: tufind root ?pattern ...? ?-option value ...?"; exit 2 }
if {[llength $argv] == 0} usage
foreach path [::tclutils::tufind::files {*}$argv] { puts $path }
