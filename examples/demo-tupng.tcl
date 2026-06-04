#!/usr/bin/env tclsh
set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tupng
package require tclutils::tuimage

set outdir [file join $here tupng-out]
file mkdir $outdir

# 1) RGB gradient (no Tk needed)
set rgb {}
for {set y 0} {$y < 64} {incr y} {
    set row {}
    for {set x 0} {$x < 64} {incr x} {
        lappend row [format %02x%02x%02x [expr {$x*4}] [expr {$y*4}] 128]
    }
    lappend rgb $row
}
::tclutils::tupng::writeRGB [file join $outdir gradient-rgb.png] $rgb

# 2) RGBA with a transparent corner
set rgba {}
for {set y 0} {$y < 32} {incr y} {
    set row {}
    for {set x 0} {$x < 32} {incr x} {
        if {$x < 16 && $y < 16} { set a 00 } else { set a ff }
        lappend row "00A0FF$a"
    }
    lappend rgba $row
}
::tclutils::tupng::writeRGBA [file join $outdir corner-rgba.png] $rgba

# 3) Grayscale ramp
set gray {}
for {set y 0} {$y < 16} {incr y} {
    set row {}
    for {set x 0} {$x < 256} {incr x} { lappend row $x }
    lappend gray $row
}
::tclutils::tupng::writeGray [file join $outdir ramp-gray.png] $gray

# 4) Indexed checkerboard, one transparent colour
set pal {FF0000 0000FF 00000000}
set idx {}
for {set y 0} {$y < 8} {incr y} {
    set row {}
    for {set x 0} {$x < 8} {incr x} { lappend row [expr {($x+$y)%2}] }
    lappend idx $row
}
::tclutils::tupng::writeIndexed [file join $outdir checker-indexed.png] $pal $idx

foreach f [lsort [glob [file join $outdir *.png]]] {
    set ch [open $f rb]; set b [read $ch]; close $ch
    puts "[file tail $f]: [::tclutils::tuimage::inspect $b], [string length $b] bytes"
}
