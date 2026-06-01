# tclutils::tubin -- binary helper primitives in pure Tcl
# Tcl 8.6+

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tubin {
    namespace export bytesToHex hexToBytes bytesToUnsignedList u8 u16le u32le u64le u16be u32be u64be packU8 packU16LE packU32LE packU64LE packU16BE packU32BE packU64BE ascii
    variable version 0.1
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

package provide tclutils::tubin 0.1
