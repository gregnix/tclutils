# tudhash-0.1.tm -- perceptual "difference hash" (dHash) in pure Tcl, Tk-free.
#
# dHash turns an image into a 64-bit fingerprint so that visually similar images
# get similar fingerprints. Two images are "the same picture" when the Hamming
# distance between their hashes is small -- useful for finding near-duplicate
# scans/photos (rescaled, recompressed, slightly cropped) where an exact byte
# hash (sha256, xxhash) would not match.
#
# This module is the Tk-free CORE: it works on a grayscale (or RGB) pixel grid.
# Decoding an image file into that grid is a separate, format-dependent step
# (Tk `image create photo` + Img, or an external converter) -- see the README.
#
# API:
#   ::tclutils::tudhash::fromGray  w h grayList        -> 16 hex chars (64-bit)
#   ::tclutils::tudhash::fromRGB   w h rgbList         -> 16 hex chars
#   ::tclutils::tudhash::distance  hexA hexB           -> 0..64 (Hamming)
#   ::tclutils::tudhash::similar   hexA hexB ?maxDist? -> bool (default 10)
#
# grayList: w*h integers 0..255, row-major.
# rgbList : w*h*3 integers 0..255, row-major (r g b r g b ...).
#
# The bit convention matches the common dHash (e.g. python `imagehash.dhash`):
# scale to 9x8, compare each pixel with its right neighbour row by row.
# Errors use errorCode {TCLUTILS TUDHASH <REASON>}.  MIT.

package require Tcl 8.6-

namespace eval ::tclutils::tudhash {
    variable HX 9   ;# sample width  (hash_size + 1)
    variable HY 8   ;# sample height (hash_size)
    namespace export fromGray fromRGB distance similar
}

proc ::tclutils::tudhash::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUDHASH $reason] $msg
}

# Box-average downscale of a w*h grayscale grid to tw*th; returns tw*th values.
proc ::tclutils::tudhash::_scale {w h grid tw th} {
    set out {}
    for {set ty 0} {$ty < $th} {incr ty} {
        set y0 [expr {int($ty * $h / $th)}]
        set y1 [expr {int(($ty + 1) * $h / $th)}]
        if {$y1 <= $y0} { set y1 [expr {$y0 + 1}] }
        for {set tx 0} {$tx < $tw} {incr tx} {
            set x0 [expr {int($tx * $w / $tw)}]
            set x1 [expr {int(($tx + 1) * $w / $tw)}]
            if {$x1 <= $x0} { set x1 [expr {$x0 + 1}] }
            set sum 0; set n 0
            for {set y $y0} {$y < $y1} {incr y} {
                set base [expr {$y * $w}]
                for {set x $x0} {$x < $x1} {incr x} {
                    incr sum [lindex $grid [expr {$base + $x}]]
                    incr n
                }
            }
            lappend out [expr {$n ? $sum / $n : 0}]
        }
    }
    return $out
}

# 8x8 difference bits from a 9x8 grid -> 16 hex chars.
proc ::tclutils::tudhash::_bits {sample} {
    variable HX
    variable HY
    set nibble 0; set count 0; set hex ""
    for {set y 0} {$y < $HY} {incr y} {
        set row [expr {$y * $HX}]
        for {set x 0} {$x < [expr {$HX - 1}]} {incr x} {
            set left  [lindex $sample [expr {$row + $x}]]
            set right [lindex $sample [expr {$row + $x + 1}]]
            set bit [expr {$right > $left ? 1 : 0}]
            set nibble [expr {($nibble << 1) | $bit}]
            if {[incr count] == 4} {
                append hex [format %x $nibble]
                set nibble 0; set count 0
            }
        }
    }
    return $hex
}

proc ::tclutils::tudhash::fromGray {w h grayList} {
    variable HX
    variable HY
    if {![string is integer -strict $w] || ![string is integer -strict $h]
        || $w < 1 || $h < 1} {
        _err DIM "width/height must be positive integers"
    }
    if {[llength $grayList] != $w * $h} {
        _err DATA "grayList has [llength $grayList] values, expected [expr {$w*$h}]"
    }
    return [_bits [_scale $w $h $grayList $HX $HY]]
}

proc ::tclutils::tudhash::fromRGB {w h rgbList} {
    if {[llength $rgbList] != $w * $h * 3} {
        _err DATA "rgbList has [llength $rgbList] values, expected [expr {$w*$h*3}]"
    }
    # luminance (integer BT.601): (77*R + 150*G + 29*B) >> 8
    set gray {}
    foreach {r g b} $rgbList {
        lappend gray [expr {(77*$r + 150*$g + 29*$b) >> 8}]
    }
    return [fromGray $w $h $gray]
}

# popcount lookup for a hex nibble
namespace eval ::tclutils::tudhash {
    variable POP
    array set POP {0 0 1 1 2 1 3 2 4 1 5 2 6 2 7 3 8 1 9 2 a 2 b 3 c 2 d 3 e 3 f 4}
}

proc ::tclutils::tudhash::distance {a b} {
    variable POP
    set a [string tolower $a]
    set b [string tolower $b]
    if {[string length $a] != 16 || [string length $b] != 16
        || ![string is xdigit -strict $a] || ![string is xdigit -strict $b]} {
        _err HASH "both hashes must be 16 hex characters"
    }
    set d 0
    for {set i 0} {$i < 16} {incr i} {
        set x [expr {("0x[string index $a $i]" ^ "0x[string index $b $i]")}]
        incr d $POP([format %x $x])
    }
    return $d
}

proc ::tclutils::tudhash::similar {a b {maxDist 10}} {
    return [expr {[distance $a $b] <= $maxDist}]
}

package provide tclutils::tudhash 0.1
