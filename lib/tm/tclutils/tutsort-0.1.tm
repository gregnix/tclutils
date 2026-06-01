# tclutils::tutsort -- tsort-like topological sort in pure Tcl
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tutsort {
    namespace export pairs text file
    variable version 0.1
}

# Topologically sort a flat list of tokens read in pairs: each pair (u v) means
# "u must come before v". A self-pair (u u) declares an isolated node with no
# ordering constraint. Returns the nodes in a stable topological order (nodes
# that become free are emitted in first-seen order). Raises on a cycle.
proc ::tclutils::tutsort::pairs {tokens} {
    if {[llength $tokens] % 2 != 0} {
        return -code error -errorcode {TCLUTILS TUTSORT ODD} \
            "input contains an odd number of tokens"
    }

    set order {}            ;# first-seen node order
    array set seen {}
    array set indeg {}
    array set succ {}       ;# node -> list of successors (with multiplicity)

    foreach {u v} $tokens {
        foreach n [list $u $v] {
            if {![info exists seen($n)]} {
                set seen($n) 1
                set indeg($n) 0
                set succ($n) {}
                lappend order $n
            }
        }
        if {$u eq $v} { continue }          ;# self-pair: declare node only
        lappend succ($u) $v
        incr indeg($v)
    }

    # Kahn's algorithm with a stable, first-seen ready order.
    set ready {}
    foreach n $order {
        if {$indeg($n) == 0} { lappend ready $n }
    }

    set result {}
    while {[llength $ready]} {
        set n [lindex $ready 0]
        set ready [lrange $ready 1 end]
        lappend result $n
        foreach m $succ($n) {
            incr indeg($m) -1
            if {$indeg($m) == 0} { lappend ready $m }
        }
    }

    if {[llength $result] != [llength $order]} {
        set remaining {}
        foreach n $order {
            if {$indeg($n) > 0} { lappend remaining $n }
        }
        return -code error -errorcode {TCLUTILS TUTSORT CYCLE} \
            "input contains a cycle involving: $remaining"
    }
    return $result
}

# Same as `pairs` but reads whitespace-separated tokens from a text.
proc ::tclutils::tutsort::text {text} {
    set tokens [regexp -all -inline {\S+} $text]
    return [join [pairs $tokens] \n]
}

proc ::tclutils::tutsort::file {path} {
    return [text [::tclutils::common::readFile $path]]
}

package provide tclutils::tutsort 0.1
