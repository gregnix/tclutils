# tclutils::tuwc -- portable word/line/char/byte counter in pure Tcl
# Description: portable word/line/char/byte counter in pure Tcl
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuwc {
    namespace export text file
    variable version 0.1
}

proc ::tclutils::tuwc::text {data} {
    set bytes [string length [encoding convertto utf-8 $data]]
    set chars [string length $data]

    if {$data eq ""} {
        set lines 0
    } else {
        set lines [regexp -all -- {\n} $data]
        if {![string match *\n $data]} {
            incr lines
        }
    }

    set words 0
    foreach w [regexp -all -inline -- {\S+} $data] {
        incr words
    }

    return [dict create lines $lines words $words chars $chars bytes $bytes]
}

proc ::tclutils::tuwc::file {filename} {
    set data [::tclutils::common::readFile $filename]
    set stats [text $data]
    dict set stats file $filename
    return $stats
}

package provide tclutils::tuwc 0.1
