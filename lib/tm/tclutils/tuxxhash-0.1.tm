# tuxxhash-0.1.tm -- xxHash32 (XXH32) in pure Tcl, Tk-free.
#
# A fast non-cryptographic hash for content de-duplication and change detection
# (not for security). The pure-Tcl implementation provides the 32-bit variant;
# it matches the reference xxHash32 bit for bit (verified against the canonical
# vectors and python-xxhash). 64/128-bit variants need the native extension.
#
# API:
#   ::tclutils::tuxxhash::xxh32     data ?seed?   -> 8 hex chars
#   ::tclutils::tuxxhash::xxh32file path ?seed?   -> 8 hex chars (whole file)
#
# Errors use errorCode {TCLUTILS TUXXHASH <REASON>}.
#
# Algorithm based on Yann Collet's xxHash (BSD-2-Clause). This module: MIT.

package require Tcl 8.6-

namespace eval ::tclutils::tuxxhash {
    variable P1 2654435761
    variable P2 2246822519
    variable P3 3266489917
    variable P4  668265263
    variable P5  374761393
    namespace export xxh32 xxh32file
}

proc ::tclutils::tuxxhash::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUXXHASH $reason] $msg
}

proc ::tclutils::tuxxhash::_rotl32 {x r} {
    set x [expr {$x & 0xFFFFFFFF}]
    return [expr {(($x << $r) | ($x >> (32 - $r))) & 0xFFFFFFFF}]
}

proc ::tclutils::tuxxhash::_round {acc val} {
    variable P1
    variable P2
    set acc [expr {($acc + ($val * $P2)) & 0xFFFFFFFF}]
    set acc [_rotl32 $acc 13]
    return [expr {($acc * $P1) & 0xFFFFFFFF}]
}

# xxh32 data ?seed? -- returns the 32-bit hash of the byte string as 8 hex chars.
# data is treated as bytes; pass a binary string (e.g. from a file) or plain
# text (its UTF-8 bytes are hashed -- encode explicitly if you need a specific
# encoding).
proc ::tclutils::tuxxhash::xxh32 {data {seed 0}} {
    variable P1
    variable P2
    variable P3
    variable P4
    variable P5
    if {![string is wideinteger -strict $seed]} {
        _err SEED "seed must be an integer, got \"$seed\""
    }
    set seed [expr {$seed & 0xFFFFFFFF}]
    set len  [string length $data]

    if {$len >= 16} {
        set v1 [expr {($seed + $P1 + $P2) & 0xFFFFFFFF}]
        set v2 [expr {($seed + $P2) & 0xFFFFFFFF}]
        set v3 $seed
        set v4 [expr {($seed - $P1) & 0xFFFFFFFF}]
        set pos 0
        while {$pos <= $len - 16} {
            binary scan [string range $data $pos       [expr {$pos + 3}]]  iu val
            set v1 [_round $v1 $val]
            binary scan [string range $data [expr {$pos + 4}]  [expr {$pos + 7}]]  iu val
            set v2 [_round $v2 $val]
            binary scan [string range $data [expr {$pos + 8}]  [expr {$pos + 11}]] iu val
            set v3 [_round $v3 $val]
            binary scan [string range $data [expr {$pos + 12}] [expr {$pos + 15}]] iu val
            set v4 [_round $v4 $val]
            incr pos 16
        }
        set h [expr {([_rotl32 $v1 1] + [_rotl32 $v2 7] + [_rotl32 $v3 12]
                      + [_rotl32 $v4 18]) & 0xFFFFFFFF}]
        set data [string range $data $pos end]
    } else {
        set h [expr {($seed + $P5) & 0xFFFFFFFF}]
    }

    set h [expr {($h + $len) & 0xFFFFFFFF}]

    set rem [string length $data]
    set pos 0
    while {$pos <= $rem - 4} {
        binary scan [string range $data $pos [expr {$pos + 3}]] iu val
        set h [expr {($h + ($val * $P3)) & 0xFFFFFFFF}]
        set h [_rotl32 $h 17]
        set h [expr {($h * $P4) & 0xFFFFFFFF}]
        incr pos 4
    }
    while {$pos < $rem} {
        binary scan [string index $data $pos] cu val
        set h [expr {($h + ($val * $P5)) & 0xFFFFFFFF}]
        set h [_rotl32 $h 11]
        set h [expr {($h * $P1) & 0xFFFFFFFF}]
        incr pos
    }

    set h [expr {($h ^ ($h >> 15)) & 0xFFFFFFFF}]
    set h [expr {($h * $P2) & 0xFFFFFFFF}]
    set h [expr {($h ^ ($h >> 13)) & 0xFFFFFFFF}]
    set h [expr {($h * $P3) & 0xFFFFFFFF}]
    set h [expr {($h ^ ($h >> 16)) & 0xFFFFFFFF}]
    return [format %08x $h]
}

# xxh32file path ?seed? -- hash the whole file's bytes.
proc ::tclutils::tuxxhash::xxh32file {path {seed 0}} {
    if {[catch {open $path rb} ch]} {
        _err IO "cannot open \"$path\": $ch"
    }
    try {
        set data [read $ch]
    } finally {
        close $ch
    }
    return [xxh32 $data $seed]
}

package provide tclutils::tuxxhash 0.1
