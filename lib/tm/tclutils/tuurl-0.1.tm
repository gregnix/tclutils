# tclutils::tuurl -- URL percent-encoding/decoding and query strings (UTF-8).
# Unreserved characters (A-Z a-z 0-9 - . _ ~) pass through; everything else is
# percent-encoded over the UTF-8 bytes. Tcl 8.6+ and 9.x.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuurl {
    namespace export encode decode buildQuery parseQuery
    variable version 0.1
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
# becomes a space.
proc ::tclutils::tuurl::decode {str args} {
    set opts [::tclutils::common::parseOptions {-plus 0} {*}$args]
    set plus [::tclutils::common::ensureBoolean [dict get $opts -plus] -plus]
    if {$plus} { set str [string map {+ " "} $str] }
    set bytes ""
    set n [string length $str]
    for {set i 0} {$i < $n} {incr i} {
        set ch [string index $str $i]
        if {$ch eq "%" && $i + 2 < $n} {
            set hex [string range $str $i+1 $i+2]
            if {[scan $hex %2x code] == 1 && [string is xdigit -strict $hex]} {
                append bytes [binary format c $code]
                incr i 2
                continue
            }
        }
        append bytes $ch
    }
    return [encoding convertfrom utf-8 $bytes]
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

package provide tclutils::tuurl 0.1
