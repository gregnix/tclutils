# tclutils::tuod -- small od-like binary dump helpers in pure Tcl
# Description: small od-like binary dump helpers in pure Tcl
# Category: Encoding · binary/checksums
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tubin 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuod {
    namespace export data file bytes
    variable version 0.1
}

proc ::tclutils::tuod::_options {args} {
    set opts [dict create -format octal -width 16 -offset 0 -length -1 -address hex]
    return [::tclutils::common::parseOptions $opts {*}$args]
}

proc ::tclutils::tuod::_byteList {bytesData offset length} {
    if {![string is integer -strict $offset] || $offset < 0} {
        return -code error -errorcode {TCLUTILS TUOD OFFSET} "-offset must be a non-negative integer"
    }
    if {![string is integer -strict $length]} {
        return -code error -errorcode {TCLUTILS TUOD LENGTH} "-length must be an integer"
    }
    return [::tclutils::tubin::bytesToUnsignedList $bytesData $offset $length]
}

proc ::tclutils::tuod::_formatAddress {n radix} {
    switch -- $radix {
        hex     { return [format %08x $n] }
        octal   { return [format %07o $n] }
        decimal { return [format %08d $n] }
        none    { return "" }
        default {
            return -code error -errorcode [list TCLUTILS TUOD ADDRESS $radix] "unknown address radix \"$radix\""
        }
    }
}

proc ::tclutils::tuod::_formatByte {b format} {
    switch -- $format {
        octal   { return [format %03o $b] }
        hex     { return [format %02x $b] }
        decimal { return [format %03d $b] }
        char {
            if {$b >= 32 && $b <= 126} { return [format %c $b] }
            return .
        }
        default {
            return -code error -errorcode [list TCLUTILS TUOD FORMAT $format] "unknown format \"$format\""
        }
    }
}

proc ::tclutils::tuod::bytes {bytesData args} {
    set opts [_options {*}$args]
    set offset [dict get $opts -offset]
    set length [dict get $opts -length]
    return [_byteList $bytesData $offset $length]
}

proc ::tclutils::tuod::data {bytesData args} {
    set opts [_options {*}$args]
    set width [dict get $opts -width]
    if {![string is integer -strict $width] || $width < 1} {
        return -code error -errorcode {TCLUTILS TUOD WIDTH} "-width must be a positive integer"
    }
    set format [dict get $opts -format]
    set address [dict get $opts -address]
    set offset [dict get $opts -offset]
    set bytes [_byteList $bytesData $offset [dict get $opts -length]]

    set out {}
    set total [llength $bytes]
    for {set i 0} {$i < $total} {incr i $width} {
        set chunk [lrange $bytes $i [expr {$i + $width - 1}]]
        set vals {}
        foreach b $chunk { lappend vals [_formatByte $b $format] }
        set addr [_formatAddress [expr {$offset + $i}] $address]
        if {$addr eq ""} {
            append out "[join $vals { }]\n"
        } else {
            append out "$addr  [join $vals { }]\n"
        }
    }
    return [string trimright $out \n]
}

proc ::tclutils::tuod::file {filename args} {
    set bytesData [::tclutils::common::readBinaryFile $filename]
    return [data $bytesData {*}$args]
}

package provide tclutils::tuod 0.1
