# tclutils::tumath -- small numeric helpers the core expr does not provide
# Description: small numeric helpers the core expr does not provide directly.
# Category: Numeric · validation
# directly. Pure Tcl, no dependencies. (For round/ceil/floor/abs use the core
# expr() math functions; those are not duplicated here.)
#
#   tumath::clamp 12 0 10      ;# 10
#   tumath::inRange 5 1 10     ;# 1
#   tumath::gcd 24 36          ;# 12
#   tumath::lcm 4 6            ;# 12
#   tumath::roundTo 3.14159 2  ;# 3.14
#   tumath::percent 30 200     ;# 15.0

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tumath {
    namespace export clamp inRange percent sign gcd lcm factorial roundTo
    variable version 0.1
}

proc ::tclutils::tumath::clamp {x lo hi} {
    if {$lo > $hi} {
        return -code error -errorcode {TCLUTILS TUMATH ARG} "lo must be <= hi"
    }
    return [expr {$x < $lo ? $lo : ($x > $hi ? $hi : $x)}]
}

proc ::tclutils::tumath::inRange {x lo hi} {
    return [expr {$x >= $lo && $x <= $hi}]
}

proc ::tclutils::tumath::percent {part whole} {
    if {$whole == 0} {
        return -code error -errorcode {TCLUTILS TUMATH DIVZERO} "whole must be non-zero"
    }
    return [expr {double($part) / $whole * 100}]
}

proc ::tclutils::tumath::sign {x} {
    return [expr {$x > 0 ? 1 : ($x < 0 ? -1 : 0)}]
}

proc ::tclutils::tumath::gcd {a b} {
    if {![string is integer -strict $a] || ![string is integer -strict $b]} {
        return -code error -errorcode {TCLUTILS TUMATH ARG} "gcd needs integers"
    }
    set a [expr {abs($a)}]
    set b [expr {abs($b)}]
    while {$b != 0} {
        set t $b
        set b [expr {$a % $b}]
        set a $t
    }
    return $a
}

proc ::tclutils::tumath::lcm {a b} {
    if {$a == 0 || $b == 0} { return 0 }
    return [expr {abs($a * $b) / [gcd $a $b]}]
}

proc ::tclutils::tumath::factorial {n} {
    if {![string is integer -strict $n] || $n < 0} {
        return -code error -errorcode {TCLUTILS TUMATH ARG} \
            "factorial needs a non-negative integer"
    }
    set r 1
    for {set i 2} {$i <= $n} {incr i} { set r [expr {$r * $i}] }
    return $r
}

# Round to $ndigits decimal places (core round() only rounds to integer).
proc ::tclutils::tumath::roundTo {x ndigits} {
    if {![string is integer -strict $ndigits] || $ndigits < 0} {
        return -code error -errorcode {TCLUTILS TUMATH ARG} \
            "ndigits must be a non-negative integer"
    }
    set f [expr {10 ** $ndigits}]
    return [expr {round($x * $f) / double($f)}]
}

package provide tclutils::tumath 0.1
