# tclutils::tubase32 -- RFC 4648 base32 (and base32hex) encode/decode.
# Tcl core provides base64 but not base32, so this is a pure-Tcl implementation.
# Tcl 8.6+ and 9.x.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tubase32 {
    namespace export encode decode encodeFile decodeFile
    variable version 0.1
    variable STD  "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    variable HEX  "0123456789ABCDEFGHIJKLMNOPQRSTUV"
    # output chars per group of 1..5 input bytes
    variable OUTCHARS {1 2 2 4 3 5 4 7 5 8}
}

proc ::tclutils::tubase32::_alphabet {hex} {
    variable STD; variable HEX
    return [expr {$hex ? $HEX : $STD}]
}

# Encode a binary string. Options: -pad bool (default 1), -hex bool (default 0,
# i.e. RFC 4648 base32; set for base32hex).
proc ::tclutils::tubase32::encode {data args} {
    variable OUTCHARS
    set opts [::tclutils::common::parseOptions {-pad 1 -hex 0} {*}$args]
    set pad [::tclutils::common::ensureBoolean [dict get $opts -pad] -pad]
    set hex [::tclutils::common::ensureBoolean [dict get $opts -hex] -hex]
    set alpha [_alphabet $hex]

    binary scan $data c* bytes
    set n [llength $bytes]
    set out ""
    for {set i 0} {$i < $n} {incr i 5} {
        set chunk [lrange $bytes $i [expr {$i + 4}]]
        set clen [llength $chunk]
        set buf 0
        for {set j 0} {$j < 5} {incr j} {
            set b [expr {$j < $clen ? ([lindex $chunk $j] & 0xff) : 0}]
            set buf [expr {($buf << 8) | $b}]
        }
        set need [dict get $OUTCHARS $clen]
        for {set k 0} {$k < 8} {incr k} {
            if {$k < $need} {
                set shift [expr {35 - $k * 5}]
                append out [string index $alpha [expr {($buf >> $shift) & 0x1f}]]
            } elseif {$pad} {
                append out "="
            }
        }
    }
    return $out
}

# Decode base32 text back to a binary string. Whitespace and "=" padding are
# ignored; input is case-insensitive. Options: -hex bool (default 0).
proc ::tclutils::tubase32::decode {text args} {
    set opts [::tclutils::common::parseOptions {-hex 0} {*}$args]
    set hex [::tclutils::common::ensureBoolean [dict get $opts -hex] -hex]
    set alpha [_alphabet $hex]

    set text [string toupper [string map {= "" " " "" \n "" \r "" \t ""} $text]]
    set bits 0
    set nbits 0
    set out ""
    foreach ch [split $text ""] {
        set v [string first $ch $alpha]
        if {$v < 0} {
            return -code error -errorcode {TCLUTILS TUBASE32 CHAR} \
                "invalid base32 character: \"$ch\""
        }
        set bits [expr {($bits << 5) | $v}]
        incr nbits 5
        if {$nbits >= 8} {
            incr nbits -8
            append out [binary format c [expr {($bits >> $nbits) & 0xff}]]
        }
    }
    return $out
}

proc ::tclutils::tubase32::encodeFile {path args} {
    return [encode [::tclutils::common::readBinaryFile $path] {*}$args]
}

proc ::tclutils::tubase32::decodeFile {path args} {
    return [decode [::tclutils::common::readFile $path] {*}$args]
}

package provide tclutils::tubase32 0.1
