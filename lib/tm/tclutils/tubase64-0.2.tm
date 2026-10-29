# tclutils::tubase64 -- base64 helpers using Tcl core binary encode/decode
# Description: base64 helpers using Tcl core binary encode/decode
# Category: Encoding · binary/checksums
# Tcl 8.6+
#
# encode takes bytes by default (-encoding binary): every character is one
# byte, a character above 255 is an error on Tcl 8.6 and 9.0 alike (8.6's
# binary encode would keep only the low byte). Text goes in with
# -encoding utf-8, which converts it first. decode returns bytes, or text
# with -encoding utf-8. The digests in tuhash and tuxxhash default to utf-8
# instead, because they are mostly used on text.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tubase64 {
    namespace export encode decode encodeFile decodeFile
    variable version 0.2
}

proc ::tclutils::tubase64::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUBASE64 $reason] $msg
}

# The bytes of $data for -encoding binary|utf-8.
proc ::tclutils::tubase64::_bytes {data enc} {
    switch -- $enc {
        binary {
            if {[regexp {[^\x00-\xff]} $data]} {
                _err BYTES "-encoding binary needs characters 0-255\
                    (use -encoding utf-8 for text)"
            }
            return $data
        }
        utf-8 { return [encoding convertto utf-8 $data] }
        default { _err ENCODING "unsupported -encoding \"$enc\" (use binary or utf-8)" }
    }
}

proc ::tclutils::tubase64::encode {data args} {
    set defaults [dict create -maxlen 0 -encoding binary]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set maxlen [dict get $opts -maxlen]
    if {![string is integer -strict $maxlen] || $maxlen < 0} {
        _err MAXLEN "-maxlen must be a non-negative integer"
    }
    set bytes [_bytes $data [dict get $opts -encoding]]
    if {$maxlen > 0} {
        return [binary encode base64 -maxlen $maxlen $bytes]
    }
    return [binary encode base64 $bytes]
}

proc ::tclutils::tubase64::decode {text args} {
    set opts [::tclutils::common::parseOptions [dict create -encoding binary] {*}$args]
    set bytes [binary decode base64 $text]
    switch -- [dict get $opts -encoding] {
        binary { return $bytes }
        utf-8  { return [encoding convertfrom utf-8 $bytes] }
        default {
            _err ENCODING "unsupported -encoding \"[dict get $opts -encoding]\"\
                (use binary or utf-8)"
        }
    }
}

proc ::tclutils::tubase64::encodeFile {path args} {
    set opts [::tclutils::common::parseOptions [dict create -maxlen 0] {*}$args]
    return [encode [::tclutils::common::readBinaryFile $path] \
        -maxlen [dict get $opts -maxlen]]
}

proc ::tclutils::tubase64::decodeFile {path} {
    return [decode [::tclutils::common::readFile $path]]
}

package provide tclutils::tubase64 0.2
