# tclutils::tuseq -- seq-like numeric sequence generation in pure Tcl
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuseq {
    namespace export range text
    variable version 0.1
}

proc ::tclutils::tuseq::_isInt {v} {
    return [string is integer -strict $v]
}

# Resolve the seq-style positional arguments into {first incr last}.
#   1 arg : last                 (first=1, incr=1)
#   2 args: first last           (incr=1)
#   3 args: first incr last
proc ::tclutils::tuseq::_resolve {positional} {
    switch [llength $positional] {
        1 { return [list 1 1 [lindex $positional 0]] }
        2 { return [list [lindex $positional 0] 1 [lindex $positional 1]] }
        3 { return [list [lindex $positional 0] [lindex $positional 1] [lindex $positional 2]] }
        default {
            return -code error -errorcode {TCLUTILS TUSEQ ARGS} \
                "wrong number of values: expected last, first last, or first incr last"
        }
    }
}

# Generate the sequence as a Tcl list of formatted numbers.
# Options: -separator (used only by `text`), -format (printf format),
#          -equalwidth 0|1 (pad numbers with leading zeros to equal width).
proc ::tclutils::tuseq::range {args} {
    set defaults [dict create -separator "\n" -format {} -equalwidth 0]
    set positional {}
    set passthrough {}
    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        if {[string match -* $a] && ![string is double -strict $a]} {
            lappend passthrough $a
            incr i
            if {$i >= [llength $args]} {
                return -code error -errorcode {TCLUTILS TUSEQ OPTION} \
                    "missing value for option \"$a\""
            }
            lappend passthrough [lindex $args $i]
        } else {
            lappend positional $a
        }
        incr i
    }
    set opts [::tclutils::common::parseOptions $defaults {*}$passthrough]
    set fmt        [dict get $opts -format]
    set equalwidth [::tclutils::common::ensureBoolean [dict get $opts -equalwidth] -equalwidth]

    lassign [_resolve $positional] first incr last
    foreach {name val} [list first $first incr $incr last $last] {
        if {![string is double -strict $val]} {
            return -code error -errorcode {TCLUTILS TUSEQ VALUE} \
                "$name is not a number: $val"
        }
    }
    if {$incr == 0} {
        return -code error -errorcode {TCLUTILS TUSEQ INCREMENT} "increment must not be zero"
    }

    set allInt [expr {[_isInt $first] && [_isInt $incr] && [_isInt $last]}]

    # Compute the element count to avoid floating-point drift.
    set span [expr {double($last) - double($first)}]
    if {($incr > 0 && $span < 0) || ($incr < 0 && $span > 0)} {
        return {}
    }
    set count [expr {int(floor($span / double($incr) + 1e-9)) + 1}]

    set values {}
    for {set k 0} {$k < $count} {incr k} {
        if {$allInt} {
            lappend values [expr {$first + $k * $incr}]
        } else {
            lappend values [expr {double($first) + $k * double($incr)}]
        }
    }

    if {$fmt ne ""} {
        set formatted {}
        foreach v $values { lappend formatted [format $fmt $v] }
        set values $formatted
    } elseif {!$allInt} {
        set formatted {}
        foreach v $values { lappend formatted [format %g $v] }
        set values $formatted
    }

    if {$equalwidth} {
        set w 0
        foreach v $values {
            set len [string length $v]
            if {$len > $w} { set w $len }
        }
        set padded {}
        foreach v $values {
            if {[string index $v 0] eq "-"} {
                lappend padded "-[format %0*s [expr {$w - 1}] [string range $v 1 end]]"
            } else {
                lappend padded [format %0*s $w $v]
            }
        }
        set values $padded
    }

    return $values
}

# Generate the sequence joined by -separator (default newline).
proc ::tclutils::tuseq::text {args} {
    set sep "\n"
    foreach {k v} $args {
        if {$k eq "-separator"} { set sep $v }
    }
    return [join [range {*}$args] $sep]
}

package provide tclutils::tuseq 0.1
