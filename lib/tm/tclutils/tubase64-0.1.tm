# tclutils::tubase64 -- base64 helpers using Tcl core binary encode/decode
# Description: base64 helpers using Tcl core binary encode/decode
# Category: Encoding · binary/checksums
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tubase64 {
    namespace export encode decode encodeFile decodeFile
    variable version 0.1
}

proc ::tclutils::tubase64::encode {data args} {
    set defaults [dict create -maxlen 0]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set maxlen [dict get $opts -maxlen]
    if {![string is integer -strict $maxlen] || $maxlen < 0} {
        return -code error -errorcode {TCLUTILS TUBASE64 MAXLEN} "-maxlen must be a non-negative integer"
    }
    if {$maxlen > 0} {
        return [binary encode base64 -maxlen $maxlen $data]
    }
    return [binary encode base64 $data]
}

proc ::tclutils::tubase64::decode {text} {
    return [binary decode base64 $text]
}

proc ::tclutils::tubase64::encodeFile {path args} {
    return [encode [::tclutils::common::readBinaryFile $path] {*}$args]
}

proc ::tclutils::tubase64::decodeFile {path} {
    return [decode [::tclutils::common::readFile $path]]
}

package provide tclutils::tubase64 0.1
