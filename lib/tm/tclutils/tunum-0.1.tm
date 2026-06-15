# tclutils::tunum -- robust parsing of human-formatted numbers and summation.
# Handles EU (1.234,56) and US (1,234.56) grouping, plain decimals, currency
# symbols and surrounding whitespace. Pure Tcl, library-neutral, no GUI.
#
# API:
#   tclutils::tunum::parse  $s ?-default {}?     -> double, or -default if unparsable
#   tclutils::tunum::sum    $values ?-default 0? -> sum of all parsable values
#   tclutils::tunum::isNumber $s                 -> 1 if parsable, else 0
#
# Tcl 8.6-
package require Tcl 8.6-

namespace eval ::tclutils::tunum {
    namespace export parse sum isNumber
    # Currency / grouping symbols stripped before parsing.
    variable strip [list "\u20AC" "" "\u0024" "" "\u00A3" "" "\u00A5" "" " " "" "\t" ""]
}

proc ::tclutils::tunum::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUNUM $reason] $msg
}

# Parse one human-formatted number. Returns a double, or $default (empty by
# default) when the string is not a recognisable number.
proc ::tclutils::tunum::parse {s args} {
    variable strip
    set default ""
    foreach {opt val} $args {
        switch -- $opt {
            -default { set default $val }
            default  { _err OPTION "unknown option \"$opt\"" }
        }
    }
    set t [string trim $s]
    set t [string map $strip $t]
    if {$t eq ""} { return $default }
    # EU format (comma = decimal, dot = grouping): 1.234,56 or 1234,56
    if {[regexp {^[+-]?\d{1,3}(\.\d{3})+,\d+$} $t] || [regexp {^[+-]?\d+,\d+$} $t]} {
        set t [string map {"." "" "," "."} $t]
    } else {
        # US format (comma = grouping): 1,234.56 -> 1234.56
        set t [string map {"," ""} $t]
    }
    if {[string is double -strict $t]} {
        return [expr {$t + 0.0}]
    }
    return $default
}

# 1 if $s parses as a number, else 0.
proc ::tclutils::tunum::isNumber {s} {
    return [expr {[parse $s -default ""] ne ""}]
}

# Sum a list of human-formatted values. Unparsable entries are skipped.
# Returns a double (or -default, default 0, when nothing was parsable).
proc ::tclutils::tunum::sum {values args} {
    set default 0
    foreach {opt val} $args {
        switch -- $opt {
            -default { set default $val }
            default  { _err OPTION "unknown option \"$opt\"" }
        }
    }
    set acc 0.0
    set any 0
    foreach v $values {
        set x [parse $v -default ""]
        if {$x ne ""} {
            set acc [expr {$acc + $x}]
            set any 1
        }
    }
    if {!$any} { return $default }
    return $acc
}

package provide tclutils::tunum 0.1
