#!/usr/bin/env tclsh
# demo-tuappinfo.tcl ?-anonymize? ?package ...?
# Loads the named packages first, then prints the report: which file each
# package came from (Loaded Packages) and which shared library was really
# loaded (Loaded Libraries). Example: tclsh demo-tuappinfo.tcl sqlite3
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tuappinfo

set anonymize 0
foreach pkg $argv {
    if {$pkg eq "-anonymize"} {
        set anonymize 1
        continue
    }
    if {[catch {package require $pkg} err]} {
        puts stderr "$pkg: $err"
    }
}
puts [::tclutils::tuappinfo::buildReport -title "demo-tuappinfo" -anonymize $anonymize]
