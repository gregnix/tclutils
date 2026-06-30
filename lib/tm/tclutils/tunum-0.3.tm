# tclutils::tunum -- robust parsing of human-formatted numbers and summation.
# Description: robust parsing of human-formatted numbers and summation.
# Category: Numeric · validation
# Handles EU (1.234,56) and US (1,234.56) grouping, plain decimals, currency
# symbols and surrounding whitespace. Pure Tcl, library-neutral, no GUI.
#
# API:
#   tclutils::tunum::parse  $s ?-default {}? ?-locale auto|de-strict?
#                                                -> double, or -default if unparsable
#   tclutils::tunum::sum    $values ?-default 0? -> sum of all parsable values
#   tclutils::tunum::isNumber $s                 -> 1 if parsable, else 0
#   tclutils::tunum::format $x ?-locale de? ?-decimals 2?
#                                                -> grouped string, e.g. 1.234,56
#
# Locales for parse:
#   auto       (default) currency strip + EU/US grouping autodetect.
#   de-strict  German strict: '.' is ALWAYS a thousands separator, ',' the
#              decimal point; no currency stripping; unparsable -> -default.
#              Equivalent to the historical Lieferschein "numDe" semantics,
#              e.g. "956.06" -> 95606.0, "1.000" -> 1000.0, ".5" -> 5.0.
#
# Tcl 8.6-
package require Tcl 8.6-

namespace eval ::tclutils::tunum {
    namespace export parse sum isNumber format
    # Currency / grouping symbols stripped before parsing (auto locale only).
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
    set locale auto
    foreach {opt val} $args {
        switch -- $opt {
            -default { set default $val }
            -locale  { set locale $val }
            default  { _err OPTION "unknown option \"$opt\"" }
        }
    }
    if {$locale ni {auto de-strict}} {
        _err LOCALE "locale must be auto or de-strict"
    }

    if {$locale eq "de-strict"} {
        # '.' = thousands (always removed), ',' = decimal. No currency strip.
        set t [string trim $s]
        if {$t eq ""} { return $default }
        set t [string map {. ""} $t]
        set t [string map {, .} $t]
        if {[string is double -strict $t]} { return [expr {double($t)}] }
        return $default
    }

    # locale auto: currency strip + EU/US autodetect.
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

# Format a number as a grouped, locale-specific string. Locale "de": dot as
# thousands separator, comma as decimal mark, $decimals fractional digits
# (rounded via [::format]). Inverse-ish of parse -locale de-strict.
# NB: this proc shadows the builtin [format] inside this namespace, so the
# builtin is called fully qualified as [::format].
proc ::tclutils::tunum::format {x args} {
    set locale de
    set decimals 2
    foreach {opt val} $args {
        switch -- $opt {
            -locale   { set locale $val }
            -decimals { set decimals $val }
            default   { _err OPTION "unknown option \"$opt\"" }
        }
    }
    if {$locale ne "de"} { _err LOCALE "format locale must be de" }
    if {![string is integer -strict $decimals] || $decimals < 0} {
        _err DECIMALS "decimals must be a non-negative integer"
    }
    set s [::format "%.*f" $decimals $x]
    set neg ""
    if {[string match -* $s]} { set neg "-"; set s [string range $s 1 end] }
    lassign [split $s .] intpart frac
    set rev [string reverse $intpart]
    set grp ""; set i 0
    foreach ch [split $rev ""] {
        if {$i > 0 && $i % 3 == 0} { append grp "." }
        append grp $ch; incr i
    }
    set intg [string reverse $grp]
    if {$decimals > 0} { return "$neg$intg,$frac" }
    return "$neg$intg"
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

package provide tclutils::tunum 0.3
