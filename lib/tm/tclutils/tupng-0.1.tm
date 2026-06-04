# tclutils::tupng -- a pure-Tcl PNG encoder (no Tk, no external packages; uses
# only the core "zlib" command). Writes 8-bit images in four colour types:
#   indexed (palette, type 3) | RGB (type 2) | RGBA (type 6) | grayscale (type 0)
#
# Image model: a list of rows, each row a list of pixels (all rows equal length).
#   RGB/RGBA pixel : "RRGGBB" / "RRGGBBAA" / "#rrggbb" / {r g b} / {r g b a}
#   grayscale pixel: an integer 0..255
#   indexed pixel  : an integer index into the supplied palette
#                    (palette entries use the RGB/RGBA pixel syntax)
#
#   set png [tupng::encodeRGB {{FF0000 00FF00} {0000FF FFFFFF}}]   ;# -> bytes
#   tupng::writeRGBA out.png $image -compression 9
#   tupng::writeIndexed out.png {FF0000 00FF0080} {{0 1} {1 0}}
#
# This is the encode-side companion to tclutils::tuimage (which inspects PNGs).
# It is indexed/RGB/RGBA/gray at 8-bit depth; it is not an interlaced or
# 16-bit encoder, and it does not decode.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tupng {
    namespace export encodeRGB encodeRGBA encodeGray encodeIndexed \
        writeRGB writeRGBA writeGray writeIndexed
    variable version 0.1
}

# --- option / value validation ----------------------------------------
proc ::tclutils::tupng::_checkLevel {v} {
    if {![string is integer -strict $v] || $v < 0 || $v > 9} {
        return -code error -errorcode {TCLUTILS TUPNG OPT} \
            "-compression must be an integer 0..9"
    }
    return $v
}
proc ::tclutils::tupng::_checkFilter {v} {
    if {$v ni {best none sub up average paeth}} {
        return -code error -errorcode {TCLUTILS TUPNG OPT} \
            "-filter must be best|none|sub|up|average|paeth"
    }
    return $v
}
proc ::tclutils::tupng::_colorErr {c} {
    return -code error -errorcode {TCLUTILS TUPNG COLOR} "invalid colour: $c"
}

# Normalise a colour to {r g b a} (a defaults to 255).
proc ::tclutils::tupng::_rgba {c} {
    set n [llength $c]
    if {$n == 3 || $n == 4} {
        foreach v $c {
            if {![string is integer -strict $v] || $v < 0 || $v > 255} { _colorErr $c }
        }
        if {$n == 3} { return [list [lindex $c 0] [lindex $c 1] [lindex $c 2] 255] }
        return $c
    }
    set h [string trim [string trimleft [lindex $c 0] #]]
    set len [string length $h]
    if {($len == 6 || $len == 8) && [string is xdigit -strict $h]} {
        if {$len == 6} {
            scan $h "%2x%2x%2x" r g b
            return [list $r $g $b 255]
        }
        scan $h "%2x%2x%2x%2x" r g b a
        return [list $r $g $b $a]
    }
    _colorErr $c
}

proc ::tclutils::tupng::_dims {image} {
    set h [llength $image]
    if {$h == 0} {
        return -code error -errorcode {TCLUTILS TUPNG DIM} "image has no rows"
    }
    set w [llength [lindex $image 0]]
    if {$w == 0} {
        return -code error -errorcode {TCLUTILS TUPNG DIM} "image rows are empty"
    }
    foreach row $image {
        if {[llength $row] != $w} {
            return -code error -errorcode {TCLUTILS TUPNG DIM} "rows have unequal length"
        }
    }
    return [list $w $h]
}

# --- scanline filtering (byte-wise, bpp-aware) -------------------------
proc ::tclutils::tupng::_applyNone {line prevline bpp} { return $line }
proc ::tclutils::tupng::_applySub {line prevline bpp} {
    set out {}
    set n [llength $line]
    for {set i 0} {$i < $n} {incr i} {
        set a [expr {$i >= $bpp ? [lindex $line [expr {$i - $bpp}]] : 0}]
        lappend out [expr {([lindex $line $i] - $a) & 0xff}]
    }
    return $out
}
proc ::tclutils::tupng::_applyUp {line prevline bpp} {
    set out {}
    set n [llength $line]
    set hasPrev [llength $prevline]
    for {set i 0} {$i < $n} {incr i} {
        set b [expr {$hasPrev ? [lindex $prevline $i] : 0}]
        lappend out [expr {([lindex $line $i] - $b) & 0xff}]
    }
    return $out
}
proc ::tclutils::tupng::_applyAverage {line prevline bpp} {
    set out {}
    set n [llength $line]
    set hasPrev [llength $prevline]
    for {set i 0} {$i < $n} {incr i} {
        set a [expr {$i >= $bpp ? [lindex $line [expr {$i - $bpp}]] : 0}]
        set b [expr {$hasPrev ? [lindex $prevline $i] : 0}]
        lappend out [expr {([lindex $line $i] - (($a + $b) >> 1)) & 0xff}]
    }
    return $out
}
proc ::tclutils::tupng::_applyPaeth {line prevline bpp} {
    set out {}
    set n [llength $line]
    set hasPrev [llength $prevline]
    for {set i 0} {$i < $n} {incr i} {
        set a [expr {$i >= $bpp ? [lindex $line [expr {$i - $bpp}]] : 0}]
        set b [expr {$hasPrev ? [lindex $prevline $i] : 0}]
        set c [expr {($i >= $bpp && $hasPrev) ? [lindex $prevline [expr {$i - $bpp}]] : 0}]
        set p [expr {$a + $b - $c}]
        set pa [expr {abs($p - $a)}]
        set pb [expr {abs($p - $b)}]
        set pc [expr {abs($p - $c)}]
        if {$pa <= $pb && $pa <= $pc} {
            set pr $a
        } elseif {$pb <= $pc} {
            set pr $b
        } else {
            set pr $c
        }
        lappend out [expr {([lindex $line $i] - $pr) & 0xff}]
    }
    return $out
}
# Minimum sum of absolute differences (signed) -- standard fast filter heuristic.
proc ::tclutils::tupng::_msad {bytes} {
    set sum 0
    foreach b $bytes { incr sum [expr {$b < 128 ? $b : 256 - $b}] }
    return $sum
}
# Pick/apply a filter for one scanline; return {typeByte filteredByteList}.
proc ::tclutils::tupng::_filterRow {line prevline bpp mode} {
    switch -- $mode {
        none    { return [list 0 [_applyNone    $line $prevline $bpp]] }
        sub     { return [list 1 [_applySub     $line $prevline $bpp]] }
        up      { return [list 2 [_applyUp      $line $prevline $bpp]] }
        average { return [list 3 [_applyAverage $line $prevline $bpp]] }
        paeth   { return [list 4 [_applyPaeth   $line $prevline $bpp]] }
        best {
            set bestType 0
            set bestData {}
            set bestScore -1
            set t 0
            foreach fl [list \
                [_applyNone    $line $prevline $bpp] \
                [_applySub     $line $prevline $bpp] \
                [_applyUp      $line $prevline $bpp] \
                [_applyAverage $line $prevline $bpp] \
                [_applyPaeth   $line $prevline $bpp]] {
                set s [_msad $fl]
                if {$bestScore < 0 || $s < $bestScore} {
                    set bestScore $s
                    set bestType $t
                    set bestData $fl
                }
                incr t
            }
            return [list $bestType $bestData]
        }
    }
}

proc ::tclutils::tupng::_filterAndCompress {rows bpp filter level} {
    set raw {}
    set prevline {}
    foreach line $rows {
        lassign [_filterRow $line $prevline $bpp $filter] t fl
        append raw [binary format c $t] [binary format c* $fl]
        set prevline $line
    }
    return [zlib compress $raw $level]
}

# --- chunk / container assembly ----------------------------------------
proc ::tclutils::tupng::_chunk {type data} {
    set btype [encoding convertto ascii $type]
    set out [binary format I [string length $data]]
    append out $btype $data
    append out [binary format I [zlib crc32 $btype$data]]
    return $out
}
proc ::tclutils::tupng::_png {colorType width height idat {plte ""} {trns ""}} {
    set out [binary format c8 {137 80 78 71 13 10 26 10}]
    append out [_chunk IHDR [binary format IIccccc $width $height 8 $colorType 0 0 0]]
    if {$plte ne ""} { append out [_chunk PLTE $plte] }
    if {$trns ne ""} { append out [_chunk tRNS $trns] }
    append out [_chunk IDAT $idat]
    append out [_chunk IEND ""]
    return $out
}

# --- public encoders (return PNG bytes) --------------------------------
proc ::tclutils::tupng::encodeRGB {image args} {
    set o [::tclutils::common::parseOptions {-compression 6 -filter best} {*}$args]
    set level [_checkLevel [dict get $o -compression]]
    set filter [_checkFilter [dict get $o -filter]]
    lassign [_dims $image] w h
    set rows {}
    foreach row $image {
        set br {}
        foreach px $row { lassign [_rgba $px] r g b a; lappend br $r $g $b }
        lappend rows $br
    }
    return [_png 2 $w $h [_filterAndCompress $rows 3 $filter $level]]
}

proc ::tclutils::tupng::encodeRGBA {image args} {
    set o [::tclutils::common::parseOptions {-compression 6 -filter best} {*}$args]
    set level [_checkLevel [dict get $o -compression]]
    set filter [_checkFilter [dict get $o -filter]]
    lassign [_dims $image] w h
    set rows {}
    foreach row $image {
        set br {}
        foreach px $row { lassign [_rgba $px] r g b a; lappend br $r $g $b $a }
        lappend rows $br
    }
    return [_png 6 $w $h [_filterAndCompress $rows 4 $filter $level]]
}

proc ::tclutils::tupng::encodeGray {image args} {
    set o [::tclutils::common::parseOptions {-compression 6 -filter best} {*}$args]
    set level [_checkLevel [dict get $o -compression]]
    set filter [_checkFilter [dict get $o -filter]]
    lassign [_dims $image] w h
    set rows {}
    foreach row $image {
        set br {}
        foreach v $row {
            if {![string is integer -strict $v] || $v < 0 || $v > 255} { _colorErr $v }
            lappend br $v
        }
        lappend rows $br
    }
    return [_png 0 $w $h [_filterAndCompress $rows 1 $filter $level]]
}

proc ::tclutils::tupng::encodeIndexed {palette image args} {
    set o [::tclutils::common::parseOptions {-compression 6 -filter best} {*}$args]
    set level [_checkLevel [dict get $o -compression]]
    set filter [_checkFilter [dict get $o -filter]]
    lassign [_dims $image] w h
    if {[llength $palette] == 0 || [llength $palette] > 256} {
        return -code error -errorcode {TCLUTILS TUPNG PALETTE} \
            "palette must have 1..256 entries"
    }
    set plte ""
    set trns {}
    set hasAlpha 0
    set psize 0
    foreach c $palette {
        lassign [_rgba $c] r g b a
        append plte [binary format ccc $r $g $b]
        lappend trns $a
        if {$a < 255} { set hasAlpha 1 }
        incr psize
    }
    set rows {}
    foreach row $image {
        set br {}
        foreach idx $row {
            if {![string is integer -strict $idx] || $idx < 0 || $idx >= $psize} {
                return -code error -errorcode {TCLUTILS TUPNG INDEX} \
                    "palette index out of range: $idx"
            }
            lappend br $idx
        }
        lappend rows $br
    }
    set trnsData [expr {$hasAlpha ? [binary format c* $trns] : ""}]
    return [_png 3 $w $h [_filterAndCompress $rows 1 $filter $level] $plte $trnsData]
}

# --- public writers (encode + write to file) ---------------------------
proc ::tclutils::tupng::_writeFile {file bytes} {
    set fid [open $file w]
    fconfigure $fid -translation binary
    puts -nonewline $fid $bytes
    close $fid
    return $file
}
proc ::tclutils::tupng::writeRGB {file image args} {
    return [_writeFile $file [encodeRGB $image {*}$args]]
}
proc ::tclutils::tupng::writeRGBA {file image args} {
    return [_writeFile $file [encodeRGBA $image {*}$args]]
}
proc ::tclutils::tupng::writeGray {file image args} {
    return [_writeFile $file [encodeGray $image {*}$args]]
}
proc ::tclutils::tupng::writeIndexed {file palette image args} {
    return [_writeFile $file [encodeIndexed $palette $image {*}$args]]
}

package provide tclutils::tupng 0.1
