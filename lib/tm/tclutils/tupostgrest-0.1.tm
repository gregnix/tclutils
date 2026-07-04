# tclutils::tupostgrest -- minimal PostgREST client (HTTP + JSON), Tk-free
# Description: minimal PostgREST REST client (HTTP + JSON)
# Category: Network · clients
#
# A small, dependency-light client for a PostgREST backend. It builds the
# request URL / query / JSON body, sends it over http(s) with an optional
# bearer token, parses the JSON response into Tcl dicts/lists and turns a
# PostgREST error response into a Tcl error.
#
# Pure Tcl (no Tk). Tcl 8.6+ / 9.x.
#
# Dependencies: http (+ tls for https), tclutils::tujson, tclutils::tuurl.
#
# A "client" is an opaque dict; pass it as the first argument to the calls:
#
#   set c [tupostgrest::new https://api.example.com -token $jwt]
#   set rows [tupostgrest::get $c documents \
#                 -filters {extension eq.pdf} -order modified_at.desc -limit 50]
#   tupostgrest::insert $c documents \
#       [dict create filename report.pdf filesize [tupostgrest::num 12345]]
#   tupostgrest::update $c documents [dict create indexed_at now] \
#       -filters {id eq.42}
#   tupostgrest::delete $c documents -filters {id eq.42}
#   set n [tupostgrest::rpc $c search_documents [dict create q "rechnung"]]
#
# Values in a row are JSON strings unless wrapped with num/bool/null:
#   tupostgrest::num 42      -> JSON number
#   tupostgrest::bool 1      -> JSON true/false
#   tupostgrest::null        -> JSON null
# (PostgREST coerces JSON strings into the target column type, so plain
#  strings are usually fine; the wrappers give explicit control.)
#
# Error codes: {TCLUTILS TUPOSTGREST <REASON>} with REASON in
#   OPTION   -- bad option / usage
#   HTTP     -- backend returned status >= 400 (message from the error JSON)
#   TRANSPORT-- the request could not be sent / no response
#   PARSE    -- the response body was not valid JSON

package require Tcl 8.6-
package require http
package require tclutils::tujson
package require tclutils::tuurl

namespace eval ::tclutils::tupostgrest {
    namespace export new configure token get insert update delete rpc request \
        num bool null
    variable version 0.1
}

proc ::tclutils::tupostgrest::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUPOSTGREST $reason] $msg
}

# --- client handle ----------------------------------------------------------
# new baseUrl ?-token jwt? ?-timeout ms? ?-header {k v ...}? ?-schema name?
#     ?-insecure 0|1?
# -insecure 1 accepts a self-signed / unverified TLS certificate (typical for
# an internal server reached by IP address).
proc ::tclutils::tupostgrest::new {baseUrl args} {
    array set o {token "" timeout 30000 header {} schema "" insecure 0}
    foreach {k v} $args {
        switch -- $k {
            -token    { set o(token)    $v }
            -timeout  { set o(timeout)  $v }
            -header   { set o(header)   $v }
            -schema   { set o(schema)   $v }
            -insecure { set o(insecure) $v }
            default   { _err OPTION "unknown option \"$k\"" }
        }
    }
    if {![string is integer -strict $o(timeout)] || $o(timeout) <= 0} {
        _err OPTION "bad -timeout \"$o(timeout)\": must be a positive integer (ms)"
    }
    return [dict create \
        base [string trimright $baseUrl /] token $o(token) \
        timeout $o(timeout) header $o(header) schema $o(schema) \
        insecure $o(insecure)]
}

# Return a copy of the client with a (new) bearer token.
proc ::tclutils::tupostgrest::token {client jwt} {
    dict set client token $jwt
    return $client
}

# --- typed value markers ----------------------------------------------------
proc ::tclutils::tupostgrest::num  {v} { return [list _pgt number  $v] }
proc ::tclutils::tupostgrest::bool {v} { return [list _pgt boolean $v] }
proc ::tclutils::tupostgrest::null {}  { return [list _pgt null    {}] }

proc ::tclutils::tupostgrest::_valTyped {v} {
    if {[llength $v] == 3 && [lindex $v 0] eq "_pgt"} {
        lassign $v _ t val
        switch -- $t {
            number  { return [::tclutils::tujson::num  $val] }
            boolean { return [::tclutils::tujson::bool $val] }
            null    { return [::tclutils::tujson::null] }
        }
    }
    return [::tclutils::tujson::str $v]
}

# A Tcl dict -> typed JSON object string.
proc ::tclutils::tupostgrest::_rowJson {row} {
    set pairs {}
    dict for {k v} $row { lappend pairs $k [_valTyped $v] }
    return [::tclutils::tujson::toJson [::tclutils::tujson::obj $pairs]]
}

# --- query building ---------------------------------------------------------
# parts: flat list {name value name value ...}; both sides are url-encoded.
proc ::tclutils::tupostgrest::_query {parts} {
    set qs {}
    foreach {k v} $parts {
        lappend qs "[::tclutils::tuurl::encode $k]=[::tclutils::tuurl::encode $v]"
    }
    return [join $qs &]
}

# Assemble the query list for a table read from the high-level options.
proc ::tclutils::tupostgrest::_readQuery {optsVar} {
    upvar 1 $optsVar o
    set q {}
    if {[info exists o(filters)]} {
        foreach {col val} $o(filters) { lappend q $col $val }
    }
    foreach {opt key} {select select order order limit limit offset offset} {
        if {[info exists o($opt)] && $o($opt) ne ""} { lappend q $key $o($opt) }
    }
    return $q
}

# --- low-level request ------------------------------------------------------
# request client METHOD path ?-query {..}? ?-body jsonString? ?-header {..}?
#         ?-prefer str?
# Returns the parsed JSON body (dict / list of dicts / scalar), or "" when the
# body is empty. Raises on HTTP >= 400 or transport failure.
proc ::tclutils::tupostgrest::request {client method path args} {
    array set o {query {} body "" header {} prefer ""}
    foreach {k v} $args {
        switch -- $k {
            -query  { set o(query)  $v }
            -body   { set o(body)   $v }
            -header { set o(header) $v }
            -prefer { set o(prefer) $v }
            default { _err OPTION "unknown option \"$k\"" }
        }
    }
    set url [dict get $client base]$path
    set qs [_query $o(query)]
    if {$qs ne ""} { append url ?$qs }

    set headers [list Accept application/json]
    if {[dict get $client token] ne ""} {
        lappend headers Authorization "Bearer [dict get $client token]"
    }
    if {[dict get $client schema] ne ""} {
        # PostgREST content negotiation for a non-default schema
        set pfx [expr {$method in {GET HEAD} ? "Accept-Profile" : "Content-Profile"}]
        lappend headers $pfx [dict get $client schema]
    }
    if {$o(prefer) ne ""} { lappend headers Prefer $o(prefer) }
    foreach {k v} [dict get $client header] { lappend headers $k $v }
    foreach {k v} $o(header)                { lappend headers $k $v }

    lassign [_transport $method $url $headers $o(body) [dict get $client timeout] \
                 [dict get $client insecure]] \
        status ctype data

    if {$status >= 400} {
        set msg "HTTP $status"
        if {[string match -nocase *json* $ctype] && [string trim $data] ne ""} {
            if {![catch {::tclutils::tujson::parse $data} ej] && \
                 [llength $ej] && [dict exists $ej message]} {
                append msg ": [dict get $ej message]"
                foreach k {details hint code} {
                    if {[dict exists $ej $k] && [dict get $ej $k] ne ""} {
                        append msg " ($k: [dict get $ej $k])"
                    }
                }
            } elseif {[string trim $data] ne ""} {
                append msg ": $data"
            }
        }
        return -code error -errorcode [list TCLUTILS TUPOSTGREST HTTP $status] $msg
    }
    if {[string trim $data] eq ""} { return "" }
    if {[catch {::tclutils::tujson::parse $data} parsed]} {
        _err PARSE "response was not valid JSON: $parsed"
    }
    return $parsed
}

# The only proc that touches the network -- override it in tests.
# Returns {status contentType data}.
proc ::tclutils::tupostgrest::_transport {method url headers body timeout {insecure 0}} {
    if {[string match -nocase https:* $url]} {
        if {[catch {package require tls}]} {
            _err TRANSPORT "https requested but the tls package is not available"
        }
        # host part, to decide on SNI
        set host ""
        regexp -nocase {^https://(\[[^\]]+\]|[^/:]+)} $url -> host
        set isIP [expr {[regexp {^\d{1,3}(\.\d{1,3}){3}$} $host] || [string match *:* $host]}]
        # SNI (-autoservername 1) must not be used with an IP literal -- some
        # tls builds reject an IP as the SNI name and http then reports
        # "failed to use socket". Send SNI only for real host names.
        set opts [list -autoservername [expr {$isIP ? 0 : 1}]]
        # self-signed / unverified certificate: don't demand validation.
        if {$insecure} { lappend opts -request 0 -require 0 }
        ::http::register https 443 [list ::tls::socket {*}$opts]
    }
    set cfg [list -method $method -timeout $timeout]
    if {[llength $headers]} { lappend cfg -headers $headers }
    if {$body ne ""}        { lappend cfg -query $body -type application/json }
    if {[catch {::http::geturl $url {*}$cfg} tok]} {
        _err TRANSPORT "request failed: $tok"
    }
    set status [::http::ncode $tok]
    set ctype  ""
    catch { set ctype [dict get [::http::meta $tok] Content-Type] }
    if {$ctype eq ""} { catch { set ctype [dict get [::http::meta $tok] content-type] } }
    set data   [::http::data $tok]
    ::http::cleanup $tok
    return [list $status $ctype $data]
}

# --- high-level verbs -------------------------------------------------------
proc ::tclutils::tupostgrest::get {client table args} {
    array set o {}
    foreach {k v} $args {
        switch -- $k {
            -filters { set o(filters) $v }
            -select  { set o(select)  $v }
            -order   { set o(order)   $v }
            -limit   { set o(limit)   $v }
            -offset  { set o(offset)  $v }
            default  { _err OPTION "unknown option \"$k\"" }
        }
    }
    return [request $client GET /$table -query [_readQuery o]]
}

# insert one row (a dict). -return 1 (default) asks PostgREST to send the row
# back (Prefer: return=representation) and the inserted rows are returned.
proc ::tclutils::tupostgrest::insert {client table row args} {
    array set o {return 1}
    foreach {k v} $args {
        switch -- $k {
            -return { set o(return) $v }
            default { _err OPTION "unknown option \"$k\"" }
        }
    }
    set prefer [expr {$o(return) ? "return=representation" : "return=minimal"}]
    return [request $client POST /$table -body [_rowJson $row] -prefer $prefer]
}

proc ::tclutils::tupostgrest::update {client table patch args} {
    array set o {return 1}
    foreach {k v} $args {
        switch -- $k {
            -filters { set o(filters) $v }
            -return  { set o(return)  $v }
            default  { _err OPTION "unknown option \"$k\"" }
        }
    }
    set q {}
    if {[info exists o(filters)]} { foreach {c val} $o(filters) { lappend q $c $val } }
    set prefer [expr {$o(return) ? "return=representation" : "return=minimal"}]
    return [request $client PATCH /$table -query $q -body [_rowJson $patch] -prefer $prefer]
}

proc ::tclutils::tupostgrest::delete {client table args} {
    array set o {return 0}
    foreach {k v} $args {
        switch -- $k {
            -filters { set o(filters) $v }
            -return  { set o(return)  $v }
            default  { _err OPTION "unknown option \"$k\"" }
        }
    }
    set q {}
    if {[info exists o(filters)]} { foreach {c val} $o(filters) { lappend q $c $val } }
    set prefer [expr {$o(return) ? "return=representation" : "return=minimal"}]
    return [request $client DELETE /$table -query $q -prefer $prefer]
}

# Call a stored function (POST /rpc/<fn> with a JSON body of the arguments).
proc ::tclutils::tupostgrest::rpc {client fn {args_ {}}} {
    return [request $client POST /rpc/$fn -body [_rowJson $args_]]
}

package provide tclutils::tupostgrest 0.1
