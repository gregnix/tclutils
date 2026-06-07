#!/usr/bin/env tclsh
# tupngpad -- bring (transparent) PNG cut-outs to a uniform size with a margin.
#
#   tclsh tupngpad.tcl -out DIR [options] file1.png file2.png ...
#
# Options:
#   -out DIR          output directory (required; created if missing)
#   -margin N         margin around the content in px (default 4)
#   -background C     background colour, flattens transparency (default white)
#   -align A          center|nw|n|ne|w|e|sw|s|se (default center)
#   -trim BOOL        auto-crop each input to its content first (default 1)
#   -square BOOL      make the output square (default 0)
#   -size {W H}       force the inner content area (default: max over inputs)
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tupngpad

set opts {}
set files {}
set outdir ""
for {set i 0} {$i < [llength $argv]} {incr i} {
    set a [lindex $argv $i]
    switch -glob -- $a {
        -out       { set outdir [lindex $argv [incr i]] }
        -margin - -background - -align - -trim - -square - -size {
            lappend opts $a [lindex $argv [incr i]]
        }
        -*         { puts stderr "unknown option: $a"; exit 2 }
        default    { lappend files $a }
    }
}
if {$outdir eq "" || [llength $files] == 0} {
    puts stderr "usage: tupngpad.tcl -out DIR \[-margin N\] \[-background C\] \[-align A\] \[-trim 0|1\] \[-square 0|1\] \[-size {W H}\] file.png ..."
    exit 2
}
set res [::tclutils::tupngpad::batch $files $outdir {*}$opts]
puts "uniform size: [join [dict get $res size] x]"
foreach {in out} [dict get $res files] { puts "  [file tail $in] -> $out" }
