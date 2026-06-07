#!/usr/bin/env tclsh
# Demos for tclutils::tucodepng (character-code table -> PNG, from tucode data).
# Dependency-free: ASCII (0..127) renders fully with the built-in bitmap font,
# so output is deterministic and identical on Tcl 8.6 and 9.x.
#
#     tclsh generate-codepage-demos.tcl ?output-dir?
#
# Output dir defaults to this script's own directory; created if missing.

set here   [file dirname [file normalize [info script]]]
set outdir [expr {[llength $argv] ? [lindex $argv 0] : $here}]
if {![file isdirectory $outdir]} {
    if {[file exists $outdir]} {
        puts stderr "first argument is an OUTPUT DIRECTORY, not a file: $outdir"
        exit 2
    }
    file mkdir $outdir
}
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tucodepng

proc out {name} { return [file join $::outdir $name] }

# full ASCII chart with hex code, glyph and name
::tclutils::tucodepng::write [out codepage-ascii.png] 0 127 \
    -scale 2 -title "ASCII 0-127" -shownames 1

# compact ASCII chart (glyph + hex only)
::tclutils::tucodepng::write [out codepage-ascii-compact.png] 0 127 -scale 2

# the lower control range, larger, with names (NUL, SOH, ... abbreviations)
::tclutils::tucodepng::write [out codepage-controls.png] 0 31 \
    -scale 3 -columns 8 -title "C0 control codes" -shownames 1

puts "wrote codepage demos to $outdir"
