# tclutils::tustrings -- extract printable strings from binary data
# Description: extract printable strings from binary data
# Category: Encoding · binary/checksums
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tustrings {
    namespace export extract file
    variable version 0.2
}

proc ::tclutils::tustrings::ParseOptions {args} {
    set opts [::tclutils::common::parseOptions [dict create -minlength 4] {*}$args]
    ::tclutils::common::ensurePositiveInteger [dict get $opts -minlength] -minlength
    return $opts
}

proc ::tclutils::tustrings::IsPrintableAscii {byte} {
    expr {$byte >= 32 && $byte <= 126}
}

proc ::tclutils::tustrings::extract {data args} {
    set opts [ParseOptions {*}$args]
    set min [dict get $opts -minlength]
    set result {}
    set current ""

    if {[regexp {[^\x00-\xff]} $data]} {
        return -code error -errorcode {TCLUTILS TUSTRINGS BYTES} "data contains characters above 255; convert text with encoding convertto first"
    }
    binary scan $data cu* bytes
    foreach b $bytes {
        if {[IsPrintableAscii $b]} {
            append current [format %c $b]
        } else {
            if {[string length $current] >= $min} {
                lappend result $current
            }
            set current ""
        }
    }
    if {[string length $current] >= $min} {
        lappend result $current
    }
    return $result
}

proc ::tclutils::tustrings::file {filename args} {
    set data [::tclutils::common::readBinaryFile $filename]
    return [extract $data {*}$args]
}

package provide tclutils::tustrings 0.2
