#!/usr/bin/env tclsh
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tupatch 0.1
proc usage {} {
    puts stderr "usage: tupatch ?-reverse 0|1? ?-strict 0|1? ?-patch patchfile? sourcefile ?outfile?"
    puts stderr "       patch is read from -patch file, or from stdin if -patch is omitted"
    exit 2
}
set opts {}
set patchFile ""
set positional {}
set i 0
while {$i < [llength $argv]} {
    set a [lindex $argv $i]
    switch -- $a {
        -reverse - -strict {
            incr i; if {$i >= [llength $argv]} usage
            lappend opts $a [lindex $argv $i]
        }
        -patch {
            incr i; if {$i >= [llength $argv]} usage
            set patchFile [lindex $argv $i]
        }
        default { lappend positional $a }
    }
    incr i
}
if {[llength $positional] < 1 || [llength $positional] > 2} usage
lassign $positional sourceFile outFile

if {$patchFile eq ""} {
    set patchText [read stdin]
} else {
    set patchText [::tclutils::common::readFile $patchFile]
}

set result [::tclutils::tupatch::fromFile $sourceFile $patchText {*}$opts]

if {[info exists outFile] && $outFile ne ""} {
    ::tclutils::common::writeFile $outFile $result
} else {
    puts -nonewline $result
    if {$result ne "" && [string index $result end] ne "\n"} { puts "" }
}
