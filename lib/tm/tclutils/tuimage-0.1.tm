# tclutils::tuimage -- pure-Tcl image inspection: detect the format, MIME type
# and pixel dimensions of an image from its raw bytes, plus data: URI helpers.
# No decoding or pixel processing (that is Tk's or imgtools' job). Tcl 8.6+/9.x.
#
#   set bytes [read $binChan]            ;# or tubase64::decode of an embedded photo
#   tuimage::type $bytes                 ;# -> png | jpeg | gif | bmp | webp | ""
#   tuimage::mime $bytes                 ;# -> image/png ...
#   tuimage::dimensions $bytes           ;# -> {width height}  (or {} if unknown)
#   tuimage::inspect $bytes              ;# -> {type .. mime .. width .. height ..}
#   tuimage::dataUri image/png $bytes    ;# -> "data:image/png;base64,...."
#   tuimage::fromDataUri $uri            ;# -> {mime image/png bytes <raw>}

package require Tcl 8.6-
package require tclutils::tubase64 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuimage {
    namespace export type mime dimensions inspect dataUri fromDataUri
    variable version 0.1
}

# --- little byte readers (unsigned, via masking; portable 8.6/9.x) ------
proc ::tclutils::tuimage::_u8 {d off} {
    if {[binary scan $d @${off}c v] != 1} { return 0 }
    return [expr {$v & 0xff}]
}
proc ::tclutils::tuimage::_u16be {d off} {
    if {[binary scan $d @${off}S v] != 1} { return 0 }
    return [expr {$v & 0xffff}]
}
proc ::tclutils::tuimage::_u16le {d off} {
    if {[binary scan $d @${off}s v] != 1} { return 0 }
    return [expr {$v & 0xffff}]
}
proc ::tclutils::tuimage::_u32be {d off} {
    if {[binary scan $d @${off}I v] != 1} { return 0 }
    return [expr {$v & 0xffffffff}]
}
proc ::tclutils::tuimage::_u32le {d off} {
    if {[binary scan $d @${off}i v] != 1} { return 0 }
    return [expr {$v & 0xffffffff}]
}

# Detect the image format from magic bytes.
proc ::tclutils::tuimage::type {bytes} {
    set n [string length $bytes]
    if {$n >= 8 && [string range $bytes 0 7] eq "\x89PNG\r\n\x1a\n"} { return png }
    if {$n >= 3 && [string range $bytes 0 2] eq "\xff\xd8\xff"}      { return jpeg }
    if {$n >= 6 && ([string range $bytes 0 5] eq "GIF87a" ||
                    [string range $bytes 0 5] eq "GIF89a")}          { return gif }
    if {$n >= 2 && [string range $bytes 0 1] eq "BM"}                { return bmp }
    if {$n >= 12 && [string range $bytes 0 3] eq "RIFF" &&
                    [string range $bytes 8 11] eq "WEBP"}            { return webp }
    return ""
}

proc ::tclutils::tuimage::mime {bytes} {
    switch -- [type $bytes] {
        png  { return image/png }
        jpeg { return image/jpeg }
        gif  { return image/gif }
        bmp  { return image/bmp }
        webp { return image/webp }
        default { return "" }
    }
}

# Return {width height}, or {} if the dimensions cannot be determined.
proc ::tclutils::tuimage::dimensions {bytes} {
    switch -- [type $bytes] {
        png  { return [_pngDims $bytes] }
        jpeg { return [_jpegDims $bytes] }
        gif  { return [_gifDims $bytes] }
        bmp  { return [_bmpDims $bytes] }
        webp { return [_webpDims $bytes] }
        default { return {} }
    }
}

proc ::tclutils::tuimage::inspect {bytes} {
    lassign [dimensions $bytes] w h
    return [dict create type [type $bytes] mime [mime $bytes] width $w height $h]
}

proc ::tclutils::tuimage::_pngDims {d} {
    if {[string length $d] < 24} { return {} }
    return [list [_u32be $d 16] [_u32be $d 20]]
}
proc ::tclutils::tuimage::_gifDims {d} {
    if {[string length $d] < 10} { return {} }
    return [list [_u16le $d 6] [_u16le $d 8]]
}
proc ::tclutils::tuimage::_bmpDims {d} {
    if {[string length $d] < 26} { return {} }
    set w [_u32le $d 18]
    set h [_u32le $d 22]
    if {$h > 0x7fffffff} { set h [expr {0x100000000 - $h}] }
    return [list $w $h]
}
proc ::tclutils::tuimage::_jpegDims {d} {
    set len [string length $d]
    set i 2
    set sof {192 193 194 195 197 198 199 201 202 203 205 206 207}
    while {$i + 4 <= $len} {
        if {[_u8 $d $i] != 0xFF} { incr i; continue }
        set marker [_u8 $d [expr {$i + 1}]]
        if {$marker == 0xD8 || $marker == 0xD9 || $marker == 0x01 ||
            ($marker >= 0xD0 && $marker <= 0xD7)} {
            incr i 2
            continue
        }
        set seglen [_u16be $d [expr {$i + 2}]]
        if {$marker in $sof} {
            if {$i + 9 > $len} { return {} }
            return [list [_u16be $d [expr {$i + 7}]] [_u16be $d [expr {$i + 5}]]]
        }
        incr i [expr {2 + $seglen}]
    }
    return {}
}
proc ::tclutils::tuimage::_webpDims {d} {
    set len [string length $d]
    if {$len < 16} { return {} }
    set cc [string range $d 12 15]
    if {$cc eq "VP8X"} {
        if {$len < 30} { return {} }
        set w [expr {([_u8 $d 24] | ([_u8 $d 25] << 8) | ([_u8 $d 26] << 16)) + 1}]
        set h [expr {([_u8 $d 27] | ([_u8 $d 28] << 8) | ([_u8 $d 29] << 16)) + 1}]
        return [list $w $h]
    } elseif {$cc eq "VP8 "} {
        if {$len < 30} { return {} }
        return [list [expr {[_u16le $d 26] & 0x3fff}] [expr {[_u16le $d 28] & 0x3fff}]]
    } elseif {$cc eq "VP8L"} {
        if {$len < 25} { return {} }
        set bits [expr {[_u8 $d 21] | ([_u8 $d 22] << 8) |
                        ([_u8 $d 23] << 16) | ([_u8 $d 24] << 24)}]
        return [list [expr {($bits & 0x3fff) + 1}] [expr {(($bits >> 14) & 0x3fff) + 1}]]
    }
    return {}
}

# --- data: URIs --------------------------------------------------------
proc ::tclutils::tuimage::dataUri {mimetype bytes} {
    return "data:$mimetype;base64,[::tclutils::tubase64::encode $bytes]"
}

# Parse a data: URI into {mime <type> bytes <raw>}. Only base64 payloads are
# decoded; a non-base64 payload is returned verbatim.
proc ::tclutils::tuimage::fromDataUri {uri} {
    if {![regexp {^data:([^,]*),(.*)$} $uri -> meta payload]} {
        return -code error -errorcode {TCLUTILS TUIMAGE DATAURI} "not a data URI"
    }
    set parts [split $meta ";"]
    set mimetype ""
    if {[lindex $parts 0] ne ""} { set mimetype [lindex $parts 0] }
    if {"base64" in $parts} {
        set bytes [::tclutils::tubase64::decode $payload]
    } else {
        set bytes $payload
    }
    return [list mime $mimetype bytes $bytes]
}

package provide tclutils::tuimage 0.1
