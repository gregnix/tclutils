# tclutils::tuurl -- URL percent-encoding/decoding and query strings (UTF-8).
# Description: URL percent-encoding/decoding and query strings (UTF-8).
# Category: Network · web
# Unreserved characters (A-Z a-z 0-9 - . _ ~) pass through; everything else is
# percent-encoded over the UTF-8 bytes. Tcl 8.6+ and 9.x.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuurl {
    namespace export encode decode buildQuery parseQuery
    variable version 0.2
}

# Percent-encode a string. Option: -plus bool (default 0). With -plus 1 a space
# becomes "+" (form-encoding) instead of "%20".
proc ::tclutils::tuurl::encode {str args} {
    set opts [::tclutils::common::parseOptions {-plus 0} {*}$args]
    set plus [::tclutils::common::ensureBoolean [dict get $opts -plus] -plus]
    set out ""
    foreach b [split [encoding convertto utf-8 $str] ""] {
        if {[string match {[-A-Za-z0-9._~]} $b]} {
            append out $b
        } elseif {$plus && $b eq " "} {
            append out "+"
        } else {
            scan $b %c code
            append out [format %%%02X $code]
        }
    }
    return $out
}

# Percent-decode a string. Option: -plus bool (default 0). With -plus 1 a "+"
# becomes a space. Characters that are not percent-encoded count as their
# UTF-8 bytes, so "J%C3%B6rg" and an already decoded "J\u00f6rg" give the same
# text (up to 0.1 Tcl 9 broke off on the second). A "%" without two hex
# digits stays as it is; %00 gives a NUL character. Invalid UTF-8 stays as
# the bytes (one character 0-255 each); up to 0.1 Tcl 9 broke off.
proc ::tclutils::tuurl::decode {str args} {
    set opts [::tclutils::common::parseOptions {-plus 0} {*}$args]
    set plus [::tclutils::common::ensureBoolean [dict get $opts -plus] -plus]
    if {$plus} { set str [string map {+ " "} $str] }
    set str [encoding convertto utf-8 $str]
    set bytes ""
    while {[set i [string first % $str]] >= 0} {
        append bytes [string range $str 0 [expr {$i - 1}]]
        set hex [string range $str [expr {$i + 1}] [expr {$i + 2}]]
        if {[string length $hex] == 2 && [string is xdigit -strict $hex]} {
            append bytes [binary format H2 $hex]
            set str [string range $str [expr {$i + 3}] end]
        } else {
            append bytes %
            set str [string range $str [expr {$i + 1}] end]
        }
    }
    append bytes $str
    if {[package vsatisfies [package provide Tcl] 9-]} {
        if {[catch {encoding convertfrom -profile strict utf-8 $bytes} t]} {
            return $bytes
        }
        return $t
    }
    set t [encoding convertfrom utf-8 $bytes]
    if {[encoding convertto utf-8 $t] ne $bytes} { return $bytes }
    return $t
}

# Build a query string "k=v&k2=v2" from a dict. Option: -plus bool (default 1).
proc ::tclutils::tuurl::buildQuery {d args} {
    set opts [::tclutils::common::parseOptions {-plus 1} {*}$args]
    set plus [::tclutils::common::ensureBoolean [dict get $opts -plus] -plus]
    set parts {}
    dict for {k v} $d {
        lappend parts "[encode $k -plus $plus]=[encode $v -plus $plus]"
    }
    return [join $parts &]
}

# Parse a query string into a dict. Option: -plus bool (default 1).
proc ::tclutils::tuurl::parseQuery {q args} {
    set opts [::tclutils::common::parseOptions {-plus 1} {*}$args]
    set plus [::tclutils::common::ensureBoolean [dict get $opts -plus] -plus]
    set d [dict create]
    foreach pair [split $q &] {
        if {$pair eq ""} continue
        set eq [string first = $pair]
        if {$eq < 0} {
            set k $pair; set v ""
        } else {
            set k [string range $pair 0 $eq-1]
            set v [string range $pair $eq+1 end]
        }
        dict set d [decode $k -plus $plus] [decode $v -plus $plus]
    }
    return $d
}

package provide tclutils::tuurl 0.2
