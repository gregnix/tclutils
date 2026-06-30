# tclutils::tushuf -- shuf-like line shuffling in pure Tcl
# Description: shuf-like line shuffling in pure Tcl
# Category: Text · strings/coreutils
# Tcl 8.6+
#
# Uses a small self-contained linear congruential generator so that a given
# -seed produces the same permutation on every platform and Tcl version,
# without relying on the interpreter's global rand() state.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tushuf {
    namespace export lines text file
    variable version 0.1
}

proc ::tclutils::tushuf::_next {stateVar} {
    upvar 1 $stateVar s
    set s [expr {($s * 1103515245 + 12345) & 0x7fffffff}]
    return $s
}

proc ::tclutils::tushuf::_shuffle {lst seed} {
    set state [expr {($seed & 0x7fffffff) ^ 0x2545f491}]
    set a $lst
    for {set i [expr {[llength $a] - 1}]} {$i > 0} {incr i -1} {
        set j [expr {[_next state] % ($i + 1)}]
        set tmp [lindex $a $i]
        lset a $i [lindex $a $j]
        lset a $j $tmp
    }
    return $a
}

# Shuffle a list of lines. Options:
#   -seed N    integer seed for reproducible output (default: time-based)
#   -count N   output at most N lines (default: all)
proc ::tclutils::tushuf::lines {lineList args} {
    set defaults [dict create -seed {} -count -1]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set seed [dict get $opts -seed]
    if {$seed eq ""} {
        set seed [expr {[clock microseconds] & 0x7fffffff}]
    } elseif {![string is integer -strict $seed]} {
        return -code error -errorcode {TCLUTILS TUSHUF SEED} "seed must be an integer: $seed"
    }
    set shuffled [_shuffle $lineList $seed]
    set count [dict get $opts -count]
    if {![string is integer -strict $count]} {
        return -code error -errorcode {TCLUTILS TUSHUF COUNT} "count must be an integer: $count"
    }
    if {$count >= 0 && $count < [llength $shuffled]} {
        set shuffled [lrange $shuffled 0 [expr {$count - 1}]]
    }
    return $shuffled
}

proc ::tclutils::tushuf::text {text args} {
    set lst [::tclutils::common::splitLines $text]
    return [join [lines $lst {*}$args] \n]
}

proc ::tclutils::tushuf::file {path args} {
    return [text [::tclutils::common::readFile $path] {*}$args]
}

package provide tclutils::tushuf 0.1
