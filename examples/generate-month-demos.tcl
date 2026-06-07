#!/usr/bin/env tclsh
# Demos for tclutils::tumonthpng (month calendar -> PNG, monthcanvas look).
# Dependency-free; deterministic (fixed -today), so output is identical on
# Tcl 8.6 and 9.x. Run from anywhere:
#
#     tclsh examples/generate-month-demos.tcl ?output-dir?
#
# Output dir defaults to this script's own directory.

set here   [file dirname [file normalize [info script]]]
set outdir [expr {[llength $argv] ? [lindex $argv 0] : $here}]
# The optional first argument is an OUTPUT DIRECTORY (not a font -- the month
# and example generators use the built-in bitmap font / shipped modules). Make
# a missing dir; reject a path that exists but is not a directory.
if {![file isdirectory $outdir]} {
    if {[file exists $outdir]} {
        puts stderr "first argument is an OUTPUT DIRECTORY, not a file: $outdir"
        puts stderr "usage: tclsh [file tail [info script]] ?output-dir?  (omit to write next to the script)"
        exit 2
    }
    file mkdir $outdir
}
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tumonthpng

proc out {name} { return [file join $::outdir $name] }

set holidays {2026-06-08 Pfingstmontag}
set notes    {2026-06-15 Zahnarzt 2026-06-22 Urlaub}

# 1) the three themes, same month, with today/holiday/notes highlighted
foreach theme {default dark light} {
    ::tclutils::tumonthpng::write [out month-$theme.png] 2026 6 \
        -theme $theme -scale 2 -today 2026-06-06 \
        -holidays $holidays -notes $notes
}

# 2) without the ISO week-number column
::tclutils::tumonthpng::write [out month-noweeks.png] 2026 6 \
    -theme default -scale 2 -today 2026-06-06 \
    -holidays $holidays -notes $notes -showweeks 0

# 3) layout variation across months (fixed -today outside these months,
#    so there is no "today" highlight and the output stays deterministic)
foreach m {1 2 12} {
    ::tclutils::tumonthpng::write [out [format month-2026-%02d.png $m]] 2026 $m \
        -theme default -scale 2 -today 2026-06-06
}


# quarter (Q1) and a full-year poster (3 columns)
::tclutils::tumonthpng::writeQuarter [out quarter-2026-Q1.png] 2026 1 \
    -theme default -scale 2 -today 2026-06-06 -holidays $holidays -notes $notes
::tclutils::tumonthpng::writeYear [out year-2026.png] 2026 \
    -theme default -scale 2 -cols 3 -today 2026-06-06 \
    -holidays {2026-01-01 Neujahr 2026-12-25 Weihnachten}

puts "wrote month demos to $outdir"
