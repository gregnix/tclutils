# tclutils::tutail -- tail-like helpers
# Description: tail-like helpers
# Category: Text · strings/coreutils
#
# 0.2: as tail -n, the result keeps the line ends: every selected line ends
# with LF, except the last line of the input when it has none. text and file
# give the same result (0.1: text took the empty rest after a final LF as a
# line, file dropped every line end). A bad count is
# {TCLUTILS TUTAIL COUNT}. file reads with -translation auto and -encoding
# (default utf-8).
package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tutail {
    namespace export text file
    variable version 0.2
}

proc ::tclutils::tutail::_count {count} {
    if {![string is integer -strict $count] || $count < 0} {
        return -code error -level 2 -errorcode {TCLUTILS TUTAIL COUNT} \
            "count must be a non-negative integer"
    }
    return $count
}

# the last COUNT lines of TEXT (default 10).
proc ::tclutils::tutail::text {text {count 10}} {
    _count $count
    if {$count == 0 || $text eq ""} { return "" }
    set nl [expr {[string index $text end] eq "\n"}]
    set lines [::tclutils::common::splitLines $text]
    set out [join [lrange $lines end-[expr {$count - 1}] end] \n]
    # the last selected line is the last line of the text: LF as there
    if {$nl} { append out \n }
    return $out
}

proc ::tclutils::tutail::file {path {count 10} args} {
    _count $count
    set o [::tclutils::common::parseOptions {-encoding utf-8} {*}$args]
    set data [::tclutils::common::readFile $path -encoding [dict get $o -encoding]]
    return [text $data $count]
}

package provide tclutils::tutail 0.2
