source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tudhash
namespace import ::tclutils::tudhash::*

# Build a w*h grayscale gradient with a little vertical offset per row, plus an
# optional brightness shift and noise -- a stand-in for "the same picture,
# slightly changed" without needing an image decoder (that is the Tk loader's
# job; see tkutils::tkudhash).
proc makeImage {w h {shift 0} {noise 0}} {
    set g {}
    for {set y 0} {$y < $h} {incr y} {
        for {set x 0} {$x < $w} {incr x} {
            set v [expr {($x * 3 + $y) % 256 + $shift}]
            if {$noise} { set v [expr {$v + int(rand() * $noise) - $noise/2}] }
            lappend g [expr {$v < 0 ? 0 : ($v > 255 ? 255 : $v)}]
        }
    }
    return $g
}

set w 120; set h 90
set orig    [fromGray $w $h [makeImage $w $h 0 0]]
set resaved [fromGray $w $h [makeImage $w $h 6 8]]   ;# brightness + noise

# a genuinely different image
proc makeOther {w h} {
    set g {}
    for {set y 0} {$y < $h} {incr y} {
        for {set x 0} {$x < $w} {incr x} { lappend g [expr {(255 - $x * 2 + $y * 5) % 256}] }
    }
    return $g
}
set other [fromGray $w $h [makeOther $w $h]]

puts "orig     = $orig"
puts "resaved  = $resaved   (same picture, brighter + noisy)"
puts "other    = $other"
puts ""
puts "distance orig<->resaved : [distance $orig $resaved]   similar? [similar $orig $resaved]"
puts "distance orig<->other   : [distance $orig $other]   similar? [similar $orig $other]"
puts ""
puts "-> small distance = near-duplicate; large distance = different image."
puts "   To hash real image files, use tkutils::tkudhash (Tk photo + Img)."
