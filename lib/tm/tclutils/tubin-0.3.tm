# tclutils::tubin -- binary helper primitives in pure Tcl
# Description: binary helper primitives in pure Tcl
# Category: Encoding · binary/checksums
# Tcl 8.6+

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tubin {
    namespace export bytesToHex hexToBytes bytesToUnsignedList u8 u16le u32le u64le u16be u32be u64be uintbe uintle f32be f64be f32le f64le i8 i16le i16be i32le i32be i64le i64be reader packU8 packU16LE packU32LE packU64LE packU16BE packU32BE packU64BE ascii
    variable version 0.3
}

proc ::tclutils::tubin::NormalizeOffset {offset} {
    if {[string match -nocase 0x* $offset]} {
        scan $offset %x n
        return $n
    }
    if {![string is integer -strict $offset] || $offset < 0} {
        return -code error -errorcode {TCLUTILS TUBIN OFFSET} "offset must be a non-negative integer"
    }
    return $offset
}

proc ::tclutils::tubin::Need {bytes offset count} {
    set offset [NormalizeOffset $offset]
    if {[string length $bytes] < $offset + $count} {
        return -code error -errorcode {TCLUTILS TUBIN SHORTDATA} "not enough bytes at offset $offset"
    }
    return $offset
}

proc ::tclutils::tubin::bytesToHex {bytes args} {
    set sep " "
    if {[llength $args] == 1} {
        set sep [lindex $args 0]
    } elseif {[llength $args] != 0} {
        return -code error "wrong # args: should be \"bytesToHex bytes ?separator?\""
    }
    binary scan $bytes H* hex
    set hex [string toupper $hex]
    set out {}
    for {set i 0} {$i < [string length $hex]} {incr i 2} {
        lappend out [string range $hex $i [expr {$i + 1}]]
    }
    return [join $out $sep]
}

proc ::tclutils::tubin::hexToBytes {hex} {
    set clean [string map [list " " "" \t "" \n "" \r "" ":" "" "-" "" "," "" "0x" "" "0X" ""] $hex]
    if {[string length $clean] % 2 != 0} {
        return -code error -errorcode {TCLUTILS TUBIN HEX ODD} "hex string must contain an even number of digits"
    }
    if {![regexp {^[0-9A-Fa-f]*$} $clean]} {
        return -code error -errorcode {TCLUTILS TUBIN HEX BADCHAR} "hex string contains non-hex characters"
    }
    return [binary format H* $clean]
}

proc ::tclutils::tubin::bytesToUnsignedList {bytes {offset 0} {length -1}} {
    set offset [NormalizeOffset $offset]
    if {![string is integer -strict $length]} {
        return -code error -errorcode {TCLUTILS TUBIN LENGTH} "length must be an integer"
    }
    if {$length >= 0} {
        set slice [string range $bytes $offset [expr {$offset + $length - 1}]]
    } else {
        set slice [string range $bytes $offset end]
    }
    binary scan $slice cu* values
    return $values
}

proc ::tclutils::tubin::u8 {bytes {offset 0}} {
    set offset [Need $bytes $offset 1]
    binary scan [string range $bytes $offset $offset] cu value
    return $value
}

proc ::tclutils::tubin::ScanUnsigned {bytes offset count format mask add} {
    set offset [Need $bytes $offset $count]
    if {[binary scan [string range $bytes $offset [expr {$offset + $count - 1}]] $format value] != 1} {
        return -code error -errorcode {TCLUTILS TUBIN SCAN} "binary scan failed"
    }
    if {$mask ne ""} {
        return [expr {$value & $mask}]
    }
    if {$value < 0} {
        return [expr {$value + $add}]
    }
    return $value
}

proc ::tclutils::tubin::u16le {bytes {offset 0}} { ScanUnsigned $bytes $offset 2 s 0xffff 0 }
proc ::tclutils::tubin::u32le {bytes {offset 0}} { ScanUnsigned $bytes $offset 4 i 0xffffffff 0 }
proc ::tclutils::tubin::u64le {bytes {offset 0}} { ScanUnsigned $bytes $offset 8 w "" [expr {1 << 64}] }
proc ::tclutils::tubin::u16be {bytes {offset 0}} { ScanUnsigned $bytes $offset 2 S 0xffff 0 }
proc ::tclutils::tubin::u32be {bytes {offset 0}} { ScanUnsigned $bytes $offset 4 I 0xffffffff 0 }
proc ::tclutils::tubin::u64be {bytes {offset 0}} { ScanUnsigned $bytes $offset 8 W "" [expr {1 << 64}] }

# --- variable-length little-endian unsigned ---------------------------------
proc ::tclutils::tubin::uintle {bytes {offset 0} {length 0}} {
    if {![string is integer -strict $length] || $length < 0} {
        return -code error -errorcode {TCLUTILS TUBIN LENGTH} "length must be a non-negative integer"
    }
    if {$length == 0} { return 0 }
    set offset [Need $bytes $offset $length]
    set v 0
    for {set i 0} {$i < $length} {incr i} {
        binary scan [string index $bytes [expr {$offset + $i}]] cu b
        set v [expr {$v | ($b << (8 * $i))}]
    }
    return $v
}

# --- signed integer readers (two's complement) ------------------------------
proc ::tclutils::tubin::Signed {value bits} {
    set half [expr {1 << ($bits - 1)}]
    if {$value >= $half} { return [expr {$value - (1 << $bits)}] }
    return $value
}
proc ::tclutils::tubin::i8    {bytes {offset 0}} { Signed [u8    $bytes $offset]  8 }
proc ::tclutils::tubin::i16le {bytes {offset 0}} { Signed [u16le $bytes $offset] 16 }
proc ::tclutils::tubin::i16be {bytes {offset 0}} { Signed [u16be $bytes $offset] 16 }
proc ::tclutils::tubin::i32le {bytes {offset 0}} { Signed [u32le $bytes $offset] 32 }
proc ::tclutils::tubin::i32be {bytes {offset 0}} { Signed [u32be $bytes $offset] 32 }
proc ::tclutils::tubin::i64le {bytes {offset 0}} { Signed [u64le $bytes $offset] 64 }
proc ::tclutils::tubin::i64be {bytes {offset 0}} { Signed [u64be $bytes $offset] 64 }

# --- IEEE-754 little-endian floats ------------------------------------------
proc ::tclutils::tubin::f32le {bytes {offset 0}} {
    set offset [Need $bytes $offset 4]
    binary scan [string range $bytes $offset [expr {$offset + 3}]] r value
    return $value
}
proc ::tclutils::tubin::f64le {bytes {offset 0}} {
    set offset [Need $bytes $offset 8]
    binary scan [string range $bytes $offset [expr {$offset + 7}]] q value
    return $value
}

proc ::tclutils::tubin::uintbe {bytes {offset 0} {length 0}} {
    # Arbitrary-length (0..N bytes) big-endian unsigned integer.
    if {![string is integer -strict $length] || $length < 0} {
        return -code error -errorcode {TCLUTILS TUBIN LENGTH} "length must be a non-negative integer"
    }
    if {$length == 0} { return 0 }
    set offset [Need $bytes $offset $length]
    set v 0
    set end [expr {$offset + $length}]
    for {set i $offset} {$i < $end} {incr i} {
        binary scan [string index $bytes $i] cu b
        set v [expr {$v * 256 + $b}]
    }
    return $v
}

proc ::tclutils::tubin::f32be {bytes {offset 0}} {
    # IEEE-754 single precision, big-endian.
    set offset [Need $bytes $offset 4]
    binary scan [string range $bytes $offset [expr {$offset + 3}]] R value
    return $value
}

proc ::tclutils::tubin::f64be {bytes {offset 0}} {
    # IEEE-754 double precision, big-endian.
    set offset [Need $bytes $offset 8]
    binary scan [string range $bytes $offset [expr {$offset + 7}]] Q value
    return $value
}

proc ::tclutils::tubin::CheckRange {value max name} {
    if {![string is integer -strict $value] || $value < 0 || $value > $max} {
        return -code error -errorcode [list TCLUTILS TUBIN RANGE $name] "$name out of range"
    }
    return $value
}

proc ::tclutils::tubin::packU8 {value} { binary format c [CheckRange $value 0xff u8] }
proc ::tclutils::tubin::packU16LE {value} { binary format s [CheckRange $value 0xffff u16] }
proc ::tclutils::tubin::packU32LE {value} { binary format i [CheckRange $value 0xffffffff u32] }
proc ::tclutils::tubin::packU64LE {value} { binary format w [CheckRange $value [expr {(1 << 64) - 1}] u64] }
proc ::tclutils::tubin::packU16BE {value} { binary format S [CheckRange $value 0xffff u16] }
proc ::tclutils::tubin::packU32BE {value} { binary format I [CheckRange $value 0xffffffff u32] }
proc ::tclutils::tubin::packU64BE {value} { binary format W [CheckRange $value [expr {(1 << 64) - 1}] u64] }

proc ::tclutils::tubin::ascii {bytes} {
    binary scan $bytes cu* values
    set out ""
    foreach b $values {
        if {$b >= 32 && $b <= 126} { append out [format %c $b] } else { append out . }
    }
    return $out
}


# --- reader cursor -----------------------------------------------------------
# A position-tracking view over a byte string, so parsers need not thread an
# offset manually. Usage:
#   set rd [::tclutils::tubin::reader new $bytes ?offset?]
#   $rd u32be ; $rd uintbe 3 ; $rd skip 4 ; $rd bytes 8 ; $rd tell ; $rd destroy
namespace eval ::tclutils::tubin {
    variable rd
    variable rdCounter 0
}

proc ::tclutils::tubin::reader {subcmd args} {
    switch -- $subcmd {
        new { return [ReaderNew {*}$args] }
        default {
            return -code error -errorcode {TCLUTILS TUBIN READER} \
                "unknown subcommand: $subcmd (expected: new)"
        }
    }
}

proc ::tclutils::tubin::ReaderNew {bytes {offset 0}} {
    variable rd
    variable rdCounter
    set name ::tclutils::tubin::rdr[incr rdCounter]
    set rd($name,data) $bytes
    set rd($name,pos)  [NormalizeOffset $offset]
    interp alias {} $name {} ::tclutils::tubin::ReaderDispatch $name
    return $name
}

proc ::tclutils::tubin::ReaderDispatch {name method args} {
    variable rd
    upvar 0 rd($name,data) data rd($name,pos) pos
    switch -- $method {
        tell      { return $pos }
        seek      { set pos [NormalizeOffset [lindex $args 0]]; return }
        skip      { incr pos [lindex $args 0]; return }
        remaining { return [expr {[string length $data] - $pos}] }
        atEnd - eof { return [expr {$pos >= [string length $data]}] }
        bytes {
            set n [lindex $args 0]
            set s [string range $data $pos [expr {$pos + $n - 1}]]
            incr pos $n
            return $s
        }
        destroy {
            interp alias {} $name {}
            array unset rd $name,*
            return
        }
        u8    { set v [u8    $data $pos]; incr pos 1; return $v }
        i8    { set v [i8    $data $pos]; incr pos 1; return $v }
        u16le { set v [u16le $data $pos]; incr pos 2; return $v }
        u16be { set v [u16be $data $pos]; incr pos 2; return $v }
        i16le { set v [i16le $data $pos]; incr pos 2; return $v }
        i16be { set v [i16be $data $pos]; incr pos 2; return $v }
        u32le { set v [u32le $data $pos]; incr pos 4; return $v }
        u32be { set v [u32be $data $pos]; incr pos 4; return $v }
        i32le { set v [i32le $data $pos]; incr pos 4; return $v }
        i32be { set v [i32be $data $pos]; incr pos 4; return $v }
        u64le { set v [u64le $data $pos]; incr pos 8; return $v }
        u64be { set v [u64be $data $pos]; incr pos 8; return $v }
        i64le { set v [i64le $data $pos]; incr pos 8; return $v }
        i64be { set v [i64be $data $pos]; incr pos 8; return $v }
        f32le { set v [f32le $data $pos]; incr pos 4; return $v }
        f32be { set v [f32be $data $pos]; incr pos 4; return $v }
        f64le { set v [f64le $data $pos]; incr pos 8; return $v }
        f64be { set v [f64be $data $pos]; incr pos 8; return $v }
        uintbe { set n [lindex $args 0]; set v [uintbe $data $pos $n]; incr pos $n; return $v }
        uintle { set n [lindex $args 0]; set v [uintle $data $pos $n]; incr pos $n; return $v }
        default {
            return -code error -errorcode {TCLUTILS TUBIN READER} \
                "unknown reader method: $method"
        }
    }
}

package provide tclutils::tubin 0.3
