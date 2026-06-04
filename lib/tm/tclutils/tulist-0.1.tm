# tclutils::tulist -- functional list helpers that the Tcl core does not provide
# directly. Pure Tcl, no dependencies. For what the core already does use that:
# [lreverse], [lsort -unique] (if you don't need order), [lsearch], [lmap]
# (script-body map/filter). The map/filter/reduce/all/any here take a *command
# prefix* (called as {*}$cmd $item) rather than a script body.
#
#   tulist::unique {a b a c b}        ;# a b c   (order-preserving)
#   tulist::chunk {1 2 3 4 5} 2       ;# {1 2} {3 4} {5}
#   tulist::zip {a b c} {1 2 3}       ;# {a 1} {b 2} {c 3}
#   tulist::map {1 2 3} {apply {{x} {expr {$x*$x}}}}   ;# 1 4 9
#   tulist::reduce {1 2 3 4} 0 ::tcl::mathop::+        ;# 10

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tulist {
    namespace export unique flatten chunk zip sum avg min max \
        reduce map filter all any take drop
    variable version 0.1
}

# Order-preserving de-duplication.
proc ::tclutils::tulist::unique {list} {
    set seen {}
    set out {}
    foreach x $list {
        if {![dict exists $seen $x]} {
            dict set seen $x 1
            lappend out $x
        }
    }
    return $out
}

# Flatten nested sublists by $depth levels (default 1).
proc ::tclutils::tulist::flatten {list {depth 1}} {
    if {$depth <= 0} { return $list }
    set out {}
    foreach x $list { lappend out {*}$x }
    if {$depth > 1} { return [flatten $out [expr {$depth - 1}]] }
    return $out
}

# Split into consecutive sublists of at most $size elements.
proc ::tclutils::tulist::chunk {list size} {
    if {![string is integer -strict $size] || $size < 1} {
        return -code error -errorcode {TCLUTILS TULIST SIZE} \
            "chunk size must be a positive integer"
    }
    set out {}
    set n [llength $list]
    for {set i 0} {$i < $n} {incr i $size} {
        lappend out [lrange $list $i [expr {$i + $size - 1}]]
    }
    return $out
}

# Zip N lists into a list of tuples, stopping at the shortest.
proc ::tclutils::tulist::zip {args} {
    if {![llength $args]} { return {} }
    set m [llength [lindex $args 0]]
    foreach l $args { set m [expr {min($m, [llength $l])}] }
    set out {}
    for {set i 0} {$i < $m} {incr i} {
        set tuple {}
        foreach l $args { lappend tuple [lindex $l $i] }
        lappend out $tuple
    }
    return $out
}

proc ::tclutils::tulist::sum {list} {
    set s 0
    foreach x $list { set s [expr {$s + $x}] }
    return $s
}
proc ::tclutils::tulist::avg {list} {
    if {![llength $list]} {
        return -code error -errorcode {TCLUTILS TULIST EMPTY} "avg of empty list"
    }
    return [expr {[sum $list] / double([llength $list])}]
}
proc ::tclutils::tulist::min {list} {
    if {![llength $list]} {
        return -code error -errorcode {TCLUTILS TULIST EMPTY} "min of empty list"
    }
    set m [lindex $list 0]
    foreach x $list { if {$x < $m} { set m $x } }
    return $m
}
proc ::tclutils::tulist::max {list} {
    if {![llength $list]} {
        return -code error -errorcode {TCLUTILS TULIST EMPTY} "max of empty list"
    }
    set m [lindex $list 0]
    foreach x $list { if {$x > $m} { set m $x } }
    return $m
}

# Left fold: acc starts at $initial, then acc = {*}$cmd $acc $item for each item.
proc ::tclutils::tulist::reduce {list initial cmd} {
    set acc $initial
    foreach x $list { set acc [uplevel #0 [list {*}$cmd $acc $x]] }
    return $acc
}

proc ::tclutils::tulist::map {list cmd} {
    set out {}
    foreach x $list { lappend out [uplevel #0 [list {*}$cmd $x]] }
    return $out
}
proc ::tclutils::tulist::filter {list cmd} {
    set out {}
    foreach x $list {
        if {[uplevel #0 [list {*}$cmd $x]]} { lappend out $x }
    }
    return $out
}
proc ::tclutils::tulist::all {list cmd} {
    foreach x $list {
        if {![uplevel #0 [list {*}$cmd $x]]} { return 0 }
    }
    return 1
}
proc ::tclutils::tulist::any {list cmd} {
    foreach x $list {
        if {[uplevel #0 [list {*}$cmd $x]]} { return 1 }
    }
    return 0
}

# First n elements / everything after the first n.
proc ::tclutils::tulist::take {list n} {
    if {$n <= 0} { return {} }
    return [lrange $list 0 [expr {$n - 1}]]
}
proc ::tclutils::tulist::drop {list n} {
    if {$n <= 0} { return $list }
    return [lrange $list $n end]
}

package provide tclutils::tulist 0.1
