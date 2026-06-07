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
# 16-bit encoder. A matching decoder (decode/readPNG) reconstructs 8-bit,
# non-interlaced PNGs of colour types 0/2/3/4/6 back to packed RGBA bytes.
#
# encodeRGBARaw/writeRGBARaw take an already-packed RGBA byte string
# (length width*height*4, row-major, 8-bit R G B A) and skip the per-pixel
# colour parsing. This is the fast path for callers that already hold a
# pixel buffer (e.g. tclutils::tupngdraw or Tk photo data).

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tupng {
    namespace export encodeRGB encodeRGBA encodeGray encodeIndexed \
        writeRGB writeRGBA writeGray writeIndexed encodeRGBARaw writeRGBARaw \
        decode readPNG
    variable version 0.2
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
    set ashift [concat [lrepeat $bpp 0] [lrange $line 0 end-$bpp]]
    return [lmap x $line a $ashift {expr {($x - $a) & 0xff}}]
}
proc ::tclutils::tupng::_applyUp {line prevline bpp} {
    if {[llength $prevline]} {
        return [lmap x $line p $prevline {expr {($x - $p) & 0xff}}]
    }
    return $line
}
proc ::tclutils::tupng::_applyAverage {line prevline bpp} {
    set n [llength $line]
    if {[llength $prevline]} {set prev $prevline} else {set prev [lrepeat $n 0]}
    set ashift [concat [lrepeat $bpp 0] [lrange $line 0 end-$bpp]]
    return [lmap x $line a $ashift b $prev {expr {($x - (($a + $b) >> 1)) & 0xff}}]
}
proc ::tclutils::tupng::_applyPaeth {line prevline bpp} {
    set n [llength $line]
    if {[llength $prevline]} {set prev $prevline} else {set prev [lrepeat $n 0]}
    set ashift [concat [lrepeat $bpp 0] [lrange $line 0 end-$bpp]]
    set cshift [concat [lrepeat $bpp 0] [lrange $prev 0 end-$bpp]]
    return [lmap x $line a $ashift b $prev c $cshift {
        set pa [expr {abs($b - $c)}]
        set pb [expr {abs($a - $c)}]
        set pc [expr {abs($a + $b - 2*$c)}]
        expr {($x - ($pa <= $pb && $pa <= $pc ? $a : ($pb <= $pc ? $b : $c))) & 0xff}
    }]
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

# --- raw (pre-packed) RGBA fast path ----------------------------------
# bytes: width*height*4 bytes, row-major, 8-bit R G B A (alpha 0..255).
proc ::tclutils::tupng::encodeRGBARaw {bytes width height args} {
    set o [::tclutils::common::parseOptions {-compression 6 -filter best} {*}$args]
    set level [_checkLevel [dict get $o -compression]]
    set filter [_checkFilter [dict get $o -filter]]
    if {![string is integer -strict $width] || $width <= 0 \
            || ![string is integer -strict $height] || $height <= 0} {
        return -code error -errorcode {TCLUTILS TUPNG DIM} \
            "width and height must be positive integers"
    }
    set need [expr {$width * $height * 4}]
    set got [string length $bytes]
    if {$got != $need} {
        return -code error -errorcode {TCLUTILS TUPNG DIM} \
            "byte length $got != width*height*4 ($need)"
    }
    binary scan $bytes cu* all
    set rows {}
    set stride [expr {$width * 4}]
    for {set y 0} {$y < $height} {incr y} {
        set off [expr {$y * $stride}]
        lappend rows [lrange $all $off [expr {$off + $stride - 1}]]
    }
    return [_png 6 $width $height [_filterAndCompress $rows 4 $filter $level]]
}
proc ::tclutils::tupng::writeRGBARaw {file bytes width height args} {
    return [_writeFile $file [encodeRGBARaw $bytes $width $height {*}$args]]
}


# --- decoder ------------------------------------------------------------
# Reconstruct an 8-bit, non-interlaced PNG (colour type 0/2/3/4/6) to packed
# RGBA. Returns a dict: width height colortype bitdepth rgba (width*height*4
# bytes, row-major R G B A). Errors carry {TCLUTILS TUPNG DECODE <reason>}.
proc ::tclutils::tupng::_paeth {a b c} {
    set p  [expr {$a + $b - $c}]
    set pa [expr {abs($p - $a)}]
    set pb [expr {abs($p - $b)}]
    set pc [expr {abs($p - $c)}]
    if {$pa <= $pb && $pa <= $pc} {return $a}
    if {$pb <= $pc} {return $b}
    return $c
}
proc ::tclutils::tupng::decode {bytes} {
    if {[string range $bytes 0 7] ne "\x89PNG\r\n\x1a\n"} {
        return -code error -errorcode {TCLUTILS TUPNG DECODE SIGNATURE} \
            "not a PNG (bad signature)"
    }
    set n [string length $bytes]
    set pos 8
    set ihdr ""; set plte ""; set trns ""; set idat ""
    while {$pos + 8 <= $n} {
        binary scan [string range $bytes $pos [expr {$pos+3}]] Iu len
        set type [string range $bytes [expr {$pos+4}] [expr {$pos+7}]]
        set dstart [expr {$pos+8}]
        set data [string range $bytes $dstart [expr {$dstart+$len-1}]]
        set pos [expr {$dstart + $len + 4}]   ;# + CRC
        switch -- $type {
            IHDR {set ihdr $data}
            PLTE {set plte $data}
            tRNS {set trns $data}
            IDAT {append idat $data}
            IEND break
        }
    }
    if {$ihdr eq ""} {
        return -code error -errorcode {TCLUTILS TUPNG DECODE IHDR} "missing IHDR"
    }
    binary scan $ihdr IuIucucucucucu width height bitdepth colortype comp filt interlace
    if {$bitdepth != 8} {
        return -code error -errorcode {TCLUTILS TUPNG DECODE BITDEPTH} \
            "only 8-bit depth is supported (got $bitdepth)"
    }
    if {$interlace != 0} {
        return -code error -errorcode {TCLUTILS TUPNG DECODE INTERLACE} \
            "interlaced PNGs are not supported"
    }
    switch -- $colortype {
        0 {set ch 1} 2 {set ch 3} 3 {set ch 1} 4 {set ch 2} 6 {set ch 4}
        default {
            return -code error -errorcode {TCLUTILS TUPNG DECODE COLORTYPE} \
                "unsupported colour type $colortype"
        }
    }
    if {$idat eq ""} {
        return -code error -errorcode {TCLUTILS TUPNG DECODE IDAT} "no image data"
    }
    set raw [zlib decompress $idat]
    binary scan $raw cu* B
    set stride [expr {$width * $ch}]
    set bpp $ch
    # palette / transparency lookup tables (indexed / colour-key)
    if {$colortype == 3} { binary scan $plte cu* PAL }
    if {$trns ne ""}     { binary scan $trns cu* TRNS }
    # un-filter scanlines -> reconstructed sample list R
    set R {}
    set ip 0
    set prev [lrepeat $stride 0]
    for {set y 0} {$y < $height} {incr y} {
        set ft [lindex $B $ip]; incr ip
        set F [lrange $B $ip [expr {$ip + $stride - 1}]]; incr ip $stride
        # Dispatch once per scanline (not per byte). none/up vectorise via lmap;
        # sub/average/paeth carry a left neighbour and stay sequential.
        switch -- $ft {
            0 { set cur $F }
            2 { set cur [lmap f $F p $prev {expr {($f + $p) & 0xff}}] }
            1 {
                set cur {}; set x 0
                foreach f $F {
                    set a [expr {$x >= $bpp ? [lindex $cur [expr {$x-$bpp}]] : 0}]
                    lappend cur [expr {($f + $a) & 0xff}]; incr x
                }
            }
            3 {
                set cur {}; set x 0
                foreach f $F p $prev {
                    set a [expr {$x >= $bpp ? [lindex $cur [expr {$x-$bpp}]] : 0}]
                    lappend cur [expr {($f + (($a + $p) >> 1)) & 0xff}]; incr x
                }
            }
            4 {
                set cur {}; set x 0
                foreach f $F b $prev {
                    set a [expr {$x >= $bpp ? [lindex $cur  [expr {$x-$bpp}]] : 0}]
                    set c [expr {$x >= $bpp ? [lindex $prev [expr {$x-$bpp}]] : 0}]
                    set pp [expr {$a + $b - $c}]
                    set pa [expr {abs($pp-$a)}]; set pb [expr {abs($pp-$b)}]; set pc [expr {abs($pp-$c)}]
                    lappend cur [expr {($f + ($pa<=$pb && $pa<=$pc ? $a : ($pb<=$pc ? $b : $c))) & 0xff}]
                    incr x
                }
            }
            default {
                return -code error -errorcode {TCLUTILS TUPNG DECODE FILTER} \
                    "bad filter type $ft"
            }
        }
        lappend R {*}$cur
        set prev $cur
    }
    # expand to RGBA
    set npix [expr {$width * $height}]
    set out {}
    switch -- $colortype {
        6 { set out $R }
        2 {
            for {set i 0} {$i < $npix} {incr i} {
                set s [expr {$i*3}]
                lappend out [lindex $R $s] [lindex $R [expr {$s+1}]] [lindex $R [expr {$s+2}]] 255
            }
        }
        0 {
            set key [expr {[info exists TRNS] ? [lindex $TRNS 1] : -1}]
            foreach g $R {
                lappend out $g $g $g [expr {$g == $key ? 0 : 255}]
            }
        }
        4 {
            for {set i 0} {$i < $npix} {incr i} {
                set s [expr {$i*2}]
                set g [lindex $R $s]
                lappend out $g $g $g [lindex $R [expr {$s+1}]]
            }
        }
        3 {
            foreach idx $R {
                set s [expr {$idx*3}]
                set al [expr {[info exists TRNS] && $idx < [llength $TRNS] ? [lindex $TRNS $idx] : 255}]
                lappend out [lindex $PAL $s] [lindex $PAL [expr {$s+1}]] [lindex $PAL [expr {$s+2}]] $al
            }
        }
    }
    return [dict create width $width height $height colortype $colortype \
        bitdepth 8 rgba [binary format cu* $out]]
}
proc ::tclutils::tupng::readPNG {file} {
    set fid [open $file r]
    fconfigure $fid -translation binary
    set bytes [read $fid]
    close $fid
    return [decode $bytes]
}

package provide tclutils::tupng 0.4
