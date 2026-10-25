# tclutils::tusparql -- a thin SPARQL client.
# Description: a thin SPARQL client.
# Category: Network · web
# Tcl 8.6+ and 9.x.
#
# It composes existing tclutils modules instead of reimplementing anything:
#   transport  -> tclutils::tufetch (GET, or POST application/sparql-query)
#   encoding   -> tclutils::tuurl    (query-string building for GET)
#   parsing    -> tclutils::tujson   (SPARQL 1.1 Results JSON)
# The only SPARQL-specific code is assembling the request and flattening the
# results-JSON bindings into a list of plain {var value ...} dicts.
#
# NOT dependency-free (inherits tufetch's http+tls / curl|wget requirement).
#
#   tusparql::query $endpoint $sparql ?-method get|post? ?-timeout ms? \
#                                     ?-headers {k v ...}? ?-accept type?
#       -> list of dicts, one per result row: {var value var value ...}
#   tusparql::ask   $endpoint $sparql ?...same opts...?
#       -> 1 | 0

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tufetch 0.2
package require tclutils::tujson 0.1
package require tclutils::tuurl 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tusparql {
    namespace export query ask
    variable version 0.2
    variable defaults {-method get -timeout 30000 -headers {} \
        -accept application/sparql-results+json}
}

# query endpoint sparql ?opts? -- run a SELECT, return a list of row dicts.
proc ::tclutils::tusparql::query {endpoint sparql args} {
    variable defaults
    set o [::tclutils::common::parseOptions $defaults {*}$args]
    return [_rows [_fetchJson $endpoint $sparql $o]]
}

# ask endpoint sparql ?opts? -- run an ASK, return 1 or 0.
proc ::tclutils::tusparql::ask {endpoint sparql args} {
    variable defaults
    set o [::tclutils::common::parseOptions $defaults {*}$args]
    return [_bool [_fetchJson $endpoint $sparql $o]]
}

# _getUrl endpoint sparql -- the GET request URL (query + format=json). Pure.
# An endpoint that already has a query string gets the parameters with "&".
proc ::tclutils::tusparql::_getUrl {endpoint sparql} {
    set qs [::tclutils::tuurl::buildQuery [list query $sparql format json]]
    if {[string first ? $endpoint] < 0} {
        return "$endpoint?$qs"
    }
    if {[string index $endpoint end] in {? &}} {
        return "$endpoint$qs"
    }
    return "$endpoint&$qs"
}

# _rows parsedDict -- flatten results-JSON bindings to a list of {var value}
# dicts. Pure. Without head vars the columns are the union of the keys of all
# bindings, in first-seen order (a later row may bind a variable the first
# one leaves unbound).
proc ::tclutils::tusparql::_rows {d} {
    if {![dict exists $d results bindings]} { return {} }
    set bindings [dict get $d results bindings]
    set vars {}
    if {[dict exists $d head vars]} { set vars [dict get $d head vars] }
    if {![llength $vars]} {
        foreach b $bindings {
            foreach k [dict keys $b] {
                if {$k ni $vars} { lappend vars $k }
            }
        }
    }
    set out {}
    foreach b $bindings {
        set row [dict create]
        foreach v $vars {
            if {[dict exists $b $v value]} { dict set row $v [dict get $b $v value] }
        }
        lappend out $row
    }
    return $out
}

# _headers o -- the request headers. Pure. An Accept in -headers (any case)
# wins over -accept; otherwise -accept is added. Accept is sent once.
proc ::tclutils::tusparql::_headers {o} {
    set headers [dict get $o -headers]
    foreach {k v} $headers {
        if {[string equal -nocase $k Accept]} { return $headers }
    }
    lappend headers Accept [dict get $o -accept]
    return $headers
}

# _bool parsedDict -- extract the ASK boolean as 1/0. Pure.
proc ::tclutils::tusparql::_bool {d} {
    if {![dict exists $d boolean]} {
        return -code error -errorcode {TCLUTILS TUSPARQL NOTASK} \
            "response has no boolean result (not an ASK query?)"
    }
    set b [dict get $d boolean]
    return [expr {($b eq "true" || $b == 1) ? 1 : 0}]
}

# _fetchJson endpoint sparql o -- perform the request, return the parsed JSON dict.
proc ::tclutils::tusparql::_fetchJson {endpoint sparql o} {
    set headers [_headers $o]
    set timeout [dict get $o -timeout]
    if {[string tolower [dict get $o -method]] eq "post"} {
        set body [::tclutils::tufetch::get $endpoint -method post -data $sparql \
            -type application/sparql-query -headers $headers -timeout $timeout]
    } else {
        set body [::tclutils::tufetch::get [_getUrl $endpoint $sparql] \
            -headers $headers -timeout $timeout]
    }
    return [::tclutils::tujson::parse $body]
}

package provide tclutils::tusparql 0.2
