# tclutils::tucrc -- CRC and Adler checksum helpers using Tcl core zlib
# Description: CRC and Adler checksum helpers using Tcl core zlib
# Category: Encoding · binary/checksums
# Tcl 8.6+
#
# crc32 and adler32 take bytes by default (-encoding binary): a character
# above 255 is an error on Tcl 8.6 and 9.0 alike (8.6's zlib would keep only
# the low byte). Text goes in with -encoding utf-8; then the checksum matches
# the one of a UTF-8 file with that text.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucrc {
    namespace export crc32 adler32 crc32File adler32File hex32
    variable version 0.2
}

proc ::tclutils::tucrc::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUCRC $reason] $msg
}

proc ::tclutils::tucrc::hex32 {value} {
    return [format %08X [expr {$value & 0xffffffff}]]
}

# Shared by crc32 and adler32: data ?initValue? ?-encoding binary|utf-8?
proc ::tclutils::tucrc::_sum {kind data argv} {
    set usage "wrong # args: should be \"$kind data ?initValue?\
        ?-encoding binary|utf-8?\""
    set init {}
    if {[llength $argv] % 2} {
        set argv [lassign $argv init]
    }
    set enc binary
    foreach {k v} $argv {
        if {$k ne "-encoding"} {
            return -code error -errorcode [list TCLUTILS TUCRC OPTION] $usage
        }
        set enc $v
    }
    switch -- $enc {
        binary {
            if {[regexp {[^\x00-\xff]} $data]} {
                _err BYTES "-encoding binary needs characters 0-255\
                    (use -encoding utf-8 for text)"
            }
        }
        utf-8 { set data [encoding convertto utf-8 $data] }
        default { _err ENCODING "unsupported -encoding \"$enc\" (use binary or utf-8)" }
    }
    if {$init eq ""} {
        return [zlib $kind $data]
    }
    return [zlib $kind $data $init]
}

proc ::tclutils::tucrc::crc32 {data args} {
    return [_sum crc32 $data $args]
}

proc ::tclutils::tucrc::adler32 {data args} {
    return [_sum adler32 $data $args]
}

proc ::tclutils::tucrc::crc32File {path} {
    return [zlib crc32 [::tclutils::common::readBinaryFile $path]]
}

proc ::tclutils::tucrc::adler32File {path} {
    return [zlib adler32 [::tclutils::common::readBinaryFile $path]]
}

package provide tclutils::tucrc 0.2
