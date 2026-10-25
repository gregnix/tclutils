# tclutils::tuseq -- seq-like numeric sequence generation in pure Tcl
# Description: seq-like numeric sequence generation in pure Tcl
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuseq {
    namespace export range text
    variable version 0.2
}

# Integer test without a size limit: under Tcl 8.6 `string is integer`
# accepts only 32-bit values, `string is entier` any size.
proc ::tclutils::tuseq::_isInt {v} {
    return [string is entier -strict $v]
}

# Split the arguments into positional values and option/value pairs. An
# argument that starts with "-" and is not a number starts an option and
# takes the next argument as its value; everything else is a value, so
# negative numbers count as values. Options may stand before, between or
# after the values.
proc ::tclutils::tuseq::_split {arglist} {
    set positional {}
    set options {}
    set i 0
    while {$i < [llength $arglist]} {
        set a [lindex $arglist $i]
        if {[string match -* $a] && ![string is double -strict $a]} {
            incr i
            if {$i >= [llength $arglist]} {
                return -code error -errorcode {TCLUTILS TUSEQ OPTION} \
                    "missing value for option \"$a\""
            }
            lappend options $a [lindex $arglist $i]
        } else {
            lappend positional $a
        }
        incr i
    }
    return [list $positional $options]
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
# Options: -format (printf format), -equalwidth 0|1 (pad numbers with
# leading zeros to equal width). -separator belongs to `text` and is
# rejected here as an unknown option.
proc ::tclutils::tuseq::range {args} {
    set defaults [dict create -format {} -equalwidth 0]
    lassign [_split $args] positional passthrough
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
    if {$allInt} {
        set count [expr {($last - $first) / $incr + 1}]
    } else {
        set count [expr {int(floor($span / double($incr) + 1e-9)) + 1}]
    }

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
# Options are recognized as in `range`, anywhere among the values.
proc ::tclutils::tuseq::text {args} {
    lassign [_split $args] positional options
    set sep "\n"
    set rest {}
    foreach {k v} $options {
        if {$k eq "-separator"} {
            set sep $v
        } else {
            lappend rest $k $v
        }
    }
    return [join [range {*}$positional {*}$rest] $sep]
}

package provide tclutils::tuseq 0.2
