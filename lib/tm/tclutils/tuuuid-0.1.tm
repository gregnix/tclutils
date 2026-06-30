# tclutils::tuuuid -- UUID generation and inspection (pure Tcl).
# Description: UUID generation and inspection (pure Tcl).
# Category: Encoding · binary/checksums
# Supports version 4 (random) and version 7 (Unix-time-ordered, RFC 9562).
# Tcl 8.6+ and 9.x.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuuuid {
    namespace export generate v4 v7 nil validate version
    variable version 0.1
}

# n random bytes: prefer /dev/urandom, fall back to rand() (non-crypto).
proc ::tclutils::tuuuid::_randomBytes {n} {
    if {[file readable /dev/urandom]} {
        if {![catch {open /dev/urandom rb} fh]} {
            set b [read $fh $n]
            close $fh
            if {[string length $b] == $n} { return $b }
        }
    }
    set b ""
    for {set i 0} {$i < $n} {incr i} {
        append b [binary format c [expr {int(rand() * 256)}]]
    }
    return $b
}

# Format 16 bytes as canonical 8-4-4-4-12 lowercase hex.
proc ::tclutils::tuuuid::_format {bytes} {
    binary scan $bytes H* h
    return [string cat \
        [string range $h 0 7] - [string range $h 8 11] - \
        [string range $h 12 15] - [string range $h 16 19] - \
        [string range $h 20 31]]
}

# Set the 4-bit version (byte 6 high nibble) and the RFC variant (byte 8).
proc ::tclutils::tuuuid::_stamp {bytesVar ver} {
    upvar 1 $bytesVar B
    lset B 6 [expr {([lindex $B 6] & 0x0f) | ($ver << 4)}]
    lset B 8 [expr {([lindex $B 8] & 0x3f) | 0x80}]
}

# Random version-4 UUID.
proc ::tclutils::tuuuid::v4 {} {
    binary scan [_randomBytes 16] cu* B
    _stamp B 4
    return [_format [binary format c* $B]]
}

# Time-ordered version-7 UUID: 48-bit Unix epoch in ms, then random.
proc ::tclutils::tuuuid::v7 {} {
    binary scan [_randomBytes 16] cu* B
    set ms [clock milliseconds]
    for {set i 5} {$i >= 0} {incr i -1} {
        lset B $i [expr {$ms & 0xff}]
        set ms [expr {$ms >> 8}]
    }
    _stamp B 7
    return [_format [binary format c* $B]]
}

# The nil UUID.
proc ::tclutils::tuuuid::nil {} {
    return "00000000-0000-0000-0000-000000000000"
}

# Generate a UUID. Option: -version 4|7 (default 4).
proc ::tclutils::tuuuid::generate {args} {
    set opts [::tclutils::common::parseOptions {-version 4} {*}$args]
    switch -- [dict get $opts -version] {
        4 { return [v4] }
        7 { return [v7] }
        default {
            return -code error -errorcode {TCLUTILS TUUUID VERSION} \
                "-version must be 4 or 7"
        }
    }
}

# Is $uuid a canonical UUID string?
proc ::tclutils::tuuuid::validate {uuid} {
    return [regexp -nocase \
        {^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$} $uuid]
}

# Version digit (1..8) of a UUID, or an error if it is not a valid UUID.
proc ::tclutils::tuuuid::version {uuid} {
    if {![validate $uuid]} {
        return -code error -errorcode {TCLUTILS TUUUID INVALID} \
            "not a valid UUID: \"$uuid\""
    }
    return [scan [string index $uuid 14] %x]
}

package provide tclutils::tuuuid 0.1
