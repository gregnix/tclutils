# tclutils::tunumfmt -- numfmt-like human-readable number formatting in pure Tcl
# Description: numfmt-like human-readable number formatting in pure Tcl
# Category: Numeric · validation
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tunumfmt {
    namespace export toHuman fromHuman text file
    variable version 0.1
}

# Ordered unit tables: {suffix divisor ...}. SI uses powers of 1000, IEC 1024.
proc ::tclutils::tunumfmt::_units {scale} {
    switch -- $scale {
        si  { return {{} K M G T P E Z Y} }
        iec { return {{} Ki Mi Gi Ti Pi Ei Zi Yi} }
        default {
            return -code error -errorcode {TCLUTILS TUNUMFMT SCALE} \
                "invalid scale \"$scale\": must be si or iec"
        }
    }
}

proc ::tclutils::tunumfmt::_base {scale} {
    return [expr {$scale eq "iec" ? 1024 : 1000}]
}

# Format a number into a human-readable string, e.g. 1500 -> "1.5K".
# Options: -to si|iec (default si), -precision N (default 1).
proc ::tclutils::tunumfmt::toHuman {number args} {
    set defaults [dict create -to si -precision 1]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set scale [dict get $opts -to]
    set prec  [dict get $opts -precision]
    if {![string is integer -strict $prec] || $prec < 0} {
        return -code error -errorcode {TCLUTILS TUNUMFMT PRECISION} \
            "precision must be a non-negative integer: $prec"
    }
    if {![string is double -strict $number]} {
        return -code error -errorcode {TCLUTILS TUNUMFMT VALUE} \
            "not a number: $number"
    }

    set units [_units $scale]
    set base  [_base $scale]
    set sign  ""
    set v [expr {double($number)}]
    if {$v < 0} { set sign "-"; set v [expr {-$v}] }

    set i 0
    set last [expr {[llength $units] - 1}]
    while {$v >= $base && $i < $last} {
        set v [expr {$v / $base}]
        incr i
    }
    set suffix [lindex $units $i]

    if {$i == 0} {
        # no scaling: emit an integer if the input was integral
        if {$number == int($number)} {
            return "$sign[expr {int($v)}]"
        }
        return "$sign[format "%.*f" $prec $v]$suffix"
    }
    return "$sign[format "%.*f" $prec $v]$suffix"
}

# Parse a human-readable string back into a number, e.g. "1.5K" -> 1500.
# Option: -from si|iec|auto (default auto; a trailing "i" implies iec).
proc ::tclutils::tunumfmt::fromHuman {str args} {
    set defaults [dict create -from auto]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set from [dict get $opts -from]

    if {![regexp {^\s*(-?[0-9]+(?:\.[0-9]+)?)\s*([A-Za-z]*)\s*$} $str -> num suffix]} {
        return -code error -errorcode {TCLUTILS TUNUMFMT PARSE} \
            "cannot parse number: $str"
    }
    if {$suffix eq ""} { return $num }

    set isIec [expr {[string match {*[iI]} $suffix]}]
    switch -- $from {
        si  { set scale si }
        iec { set scale iec }
        auto { set scale [expr {$isIec ? "iec" : "si"}] }
        default {
            return -code error -errorcode {TCLUTILS TUNUMFMT FROM} \
                "invalid -from \"$from\": must be si, iec, or auto"
        }
    }

    set letter [string toupper [string index $suffix 0]]
    set base [_base $scale]
    set table {K 1 M 2 G 3 T 4 P 5 E 6 Z 7 Y 8}
    if {![dict exists $table $letter]} {
        return -code error -errorcode {TCLUTILS TUNUMFMT SUFFIX} \
            "unknown unit suffix: $suffix"
    }
    set power [dict get $table $letter]
    set factor [expr {entier(pow($base, $power))}]
    set result [expr {$num * $factor}]
    # return an integer when the math is exact
    if {$result == int($result)} { return [expr {entier($result)}] }
    return $result
}

# Process a text line by line. Option -mode to|from (default to) plus the options
# of the chosen direction.
proc ::tclutils::tunumfmt::text {text args} {
    set mode to
    set rest {}
    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        if {$a eq "-mode"} {
            incr i
            if {$i >= [llength $args]} {
                return -code error -errorcode {TCLUTILS TUNUMFMT OPTION} "missing value for option \"-mode\""
            }
            set mode [lindex $args $i]
        } else {
            lappend rest $a
        }
        incr i
    }
    if {$mode ni {to from}} {
        return -code error -errorcode {TCLUTILS TUNUMFMT MODE} \
            "invalid -mode \"$mode\": must be to or from"
    }

    set trailing 0
    set lines [split $text \n]
    if {$text ne "" && [string index $text end] eq "\n"} {
        set lines [lrange $lines 0 end-1]
        set trailing 1
    }
    set out {}
    foreach line $lines {
        if {[string trim $line] eq ""} {
            lappend out $line
        } elseif {$mode eq "to"} {
            lappend out [toHuman [string trim $line] {*}$rest]
        } else {
            lappend out [fromHuman $line {*}$rest]
        }
    }
    set result [join $out \n]
    if {$trailing} { append result \n }
    return $result
}

proc ::tclutils::tunumfmt::file {path args} {
    return [text [::tclutils::common::readFile $path] {*}$args]
}

package provide tclutils::tunumfmt 0.1
