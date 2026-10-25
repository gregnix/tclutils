# tclutils::tuvalidate -- small format/type validation predicates. Each returns
# Description: small format/type validation predicates.
# Category: Numeric · validation
# a boolean (1/0); they never throw on the value being validated (only on bad
# *arguments*, e.g. a non-integer bound). Pure Tcl, no dependencies.
#
# These are pragmatic format checks, not full RFC validators: email/url in
# particular accept the common shapes and reject the obviously broken ones.
#
#   tuvalidate::email "a@b.com"      ;# 1
#   tuvalidate::ipv4  "10.0.0.256"   ;# 0  (octet out of range)
#   tuvalidate::length $s 3 20       ;# 1 if 3 <= [string length $s] <= 20
#   tuvalidate::inList $x {a b c}    ;# membership

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tuvalidate {
    namespace export email url ipv4 port alpha alnum numeric integer \
        length pattern inList
    variable version 0.2
}

proc ::tclutils::tuvalidate::email {s} {
    return [regexp {^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$} $s]
}

proc ::tclutils::tuvalidate::url {s} {
    return [regexp {^https?://[^\s/$.?#][^\s]*$} $s]
}

# Dotted-quad IPv4 in strict form (as inet_pton): four decimal octets
# 0..255, no leading zeros ("010" is rejected, "0" is fine), no whitespace.
proc ::tclutils::tuvalidate::ipv4 {s} {
    set oct {(0|[1-9][0-9]{0,2})}
    if {![regexp "^$oct\\.$oct\\.$oct\\.$oct\$" $s -> a b c d]} {
        return 0
    }
    foreach o [list $a $b $c $d] {
        if {$o > 255} { return 0 }
    }
    return 1
}

# TCP/UDP port: ASCII decimal digits only (no sign, no whitespace, no 0x),
# leading zeros allowed and read as decimal ("080" is 80), value 1..65535.
# Same result under Tcl 8.6 and 9.
proc ::tclutils::tuvalidate::port {s} {
    if {![regexp {^[0-9]+$} $s]} { return 0 }
    set d [string trimleft $s 0]
    if {$d eq "" || [string length $d] > 5} { return 0 }
    return [expr {$d >= 1 && $d <= 65535}]
}

# ASCII letters / letters+digits (Unicode-aware checks: use [string is alpha]).
proc ::tclutils::tuvalidate::alpha {s} { return [regexp {^[A-Za-z]+$} $s] }
proc ::tclutils::tuvalidate::alnum {s} { return [regexp {^[A-Za-z0-9]+$} $s] }

proc ::tclutils::tuvalidate::numeric {s} { return [string is double -strict $s] }
proc ::tclutils::tuvalidate::integer {s} { return [string is integer -strict $s] }

proc ::tclutils::tuvalidate::length {s min max} {
    if {![string is integer -strict $min] || ![string is integer -strict $max]} {
        return -code error -errorcode {TCLUTILS TUVALIDATE ARG} \
            "min/max must be integers"
    }
    set n [string length $s]
    return [expr {$n >= $min && $n <= $max}]
}

proc ::tclutils::tuvalidate::pattern {s re} {
    if {[catch {regexp -- $re $s} ok]} {
        return -code error -errorcode {TCLUTILS TUVALIDATE REGEX} \
            "invalid regular expression"
    }
    return [expr {$ok ? 1 : 0}]
}

proc ::tclutils::tuvalidate::inList {s list} {
    return [expr {$s in $list}]
}

package provide tclutils::tuvalidate 0.2
