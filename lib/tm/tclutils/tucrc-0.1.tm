# tclutils::tucrc -- CRC and Adler checksum helpers using Tcl core zlib
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucrc {
    namespace export crc32 adler32 crc32File adler32File hex32
    variable version 0.1
}

proc ::tclutils::tucrc::hex32 {value} {
    return [format %08X [expr {$value & 0xffffffff}]]
}

proc ::tclutils::tucrc::crc32 {data args} {
    if {[llength $args] == 0} {
        return [zlib crc32 $data]
    } elseif {[llength $args] == 1} {
        return [zlib crc32 $data [lindex $args 0]]
    }
    return -code error "wrong # args: should be \"crc32 data ?initValue?\""
}

proc ::tclutils::tucrc::adler32 {data args} {
    if {[llength $args] == 0} {
        return [zlib adler32 $data]
    } elseif {[llength $args] == 1} {
        return [zlib adler32 $data [lindex $args 0]]
    }
    return -code error "wrong # args: should be \"adler32 data ?initValue?\""
}

proc ::tclutils::tucrc::crc32File {path} {
    return [crc32 [::tclutils::common::readBinaryFile $path]]
}

proc ::tclutils::tucrc::adler32File {path} {
    return [adler32 [::tclutils::common::readBinaryFile $path]]
}

package provide tclutils::tucrc 0.1
