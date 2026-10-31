# tclutils::tunumany -- a single entry point for "string -> number" that routes
# Description: a single entry point for string-to-number that routes to the right backend
# Category: Numeric · validation
# to the right backend instead of merging them:
#   * locale-grouped / currency amounts ("1.234,56 €", "1,234.56") -> tunum::parse
#   * SI/IEC unit notation ("1.5K", "2Mi", "3G")                   -> tunumfmt::fromHuman
# This keeps the two specialised parsers separate (they do not overlap) while
# offering callers one function that recognises both notations.
#
# API:
#   tclutils::tunumany::parse str ?-default VAL? ?-prefer auto|si|locale?
#       -> number, or VAL (default "") when nothing parses
#
# Detection (with -prefer auto): a value that is a plain number followed by an
# SI/IEC unit letter (K M G T P E Z Y, optional trailing "i") routes to the
# SI/IEC backend; everything else routes to the locale/currency backend. Use
# -prefer si|locale to force a route. A decimal comma before the unit counts
# ("1,5K" is 1500); with exactly three digits after the comma ("1,500K") the
# comma could be a group separator, so that form does not parse.
#
# Tcl 8.6-
package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tunumany {
    namespace export parse
}

proc ::tclutils::tunumany::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUNUMANY $reason] $msg
}

# True when the trimmed string looks like SI/IEC unit notation (number + unit).
proc ::tclutils::tunumany::_looksSi {t} {
    return [regexp {^[+-]?[0-9]+(?:[.,][0-9]+)?[ ]*[KMGTPEZYkmgtpezy]i?$} $t]
}

proc ::tclutils::tunumany::_si {t} {
    if {[catch {package require tclutils::tunumfmt}]} { return "" }
    # decimal comma before the unit; three digits after it are ambiguous
    if {[regexp {^([+-]?[0-9]+),([0-9]+)(.*)$} $t -> a b rest]} {
        if {[string length $b] == 3} { return "" }
        set t $a.$b$rest
    }
    if {[catch {::tclutils::tunumfmt::fromHuman $t} v]} { return "" }
    return $v
}

proc ::tclutils::tunumany::_locale {t} {
    if {[catch {package require tclutils::tunum}]} { return "" }
    return [::tclutils::tunum::parse $t -default ""]
}

# Parse a numeric string in either notation.
proc ::tclutils::tunumany::parse {str args} {
    set default ""
    set prefer auto
    if {[llength $args] % 2} {
        _err OPTION "option \"[lindex $args end]\" requires a value"
    }
    foreach {k v} $args {
        switch -- $k {
            -default { set default $v }
            -prefer  { set prefer $v }
            default  { _err OPTION "unknown option \"$k\"" }
        }
    }
    if {$prefer ni {auto si locale}} {
        _err PREFER "prefer must be auto, si or locale"
    }
    set t [string trim $str]
    if {$t eq ""} { return $default }

    set route $prefer
    if {$route eq "auto"} {
        if {[_looksSi $t]} {
            set route si
        } else {
            set route locale
        }
    }

    if {$route eq "si"} {
        set v [_si $t]
        if {$v ne ""} { return $v }
        set v [_locale $t]
        if {$v ne ""} { return $v }
    } else {
        set v [_locale $t]
        if {$v ne ""} { return $v }
        set v [_si $t]
        if {$v ne ""} { return $v }
    }
    return $default
}

package provide tclutils::tunumany 0.3
