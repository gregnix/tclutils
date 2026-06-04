# tclutils::tudav -- a minimal WebDAV / CardDAV / CalDAV client.
#
# Create a client bound to a base URL and credentials, then run PROPFIND /
# REPORT / GET / PUT / DELETE. Multistatus responses are parsed into a list of
# resource dicts (href, status, etag, contenttype, collection, displayname).
# Built on the Tcl core http package; https uses the tls package (loaded
# lazily on first use). Basic auth uses tclutils::tubase64; href/etag text is
# entity-decoded with tclutils::tuxml. Tcl 8.6+ and 9.x.
#
# This client does not parse the resource bodies themselves -- feed a fetched
# vCard to tclutils::tuvcard or an iCalendar to tclutils::tuical.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tubase64 0.1
package require tclutils::tuxml 0.1
package require http

namespace eval ::tclutils {}
namespace eval ::tclutils::tudav {
    namespace export client configure destroy \
        propfind report listResources get put delete lastStatus \
        calendarQuery addressbookMultiget
    variable state
    variable seq 0
    variable tlsReady 0
}

proc ::tclutils::tudav::_check {c} {
    variable state
    if {![info exists state($c)]} {
        return -code error -errorcode {TCLUTILS TUDAV CLIENT} \
            "unknown dav client: \"$c\""
    }
}

# --- pure helpers (testable without a server) ----------------------------

# Basic authorization header value for user:pass.
proc ::tclutils::tudav::_basicAuth {user pass} {
    return "Basic [::tclutils::tubase64::encode $user:$pass]"
}

# Resolve a possibly relative href against a base URL.
proc ::tclutils::tudav::_resolve {base href} {
    if {$href eq ""} {
        if {[regexp {^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]+$} $base]} { return "$base/" }
        return $base
    }
    if {[regexp {^[a-zA-Z][a-zA-Z0-9+.-]*://} $href]} { return $href }
    if {![regexp {^([a-zA-Z][a-zA-Z0-9+.-]*://[^/]+)(/.*)?$} $base -> origin rest]} {
        # base is not a full URL; fall back to simple join
        if {[string match */ $base]} { return $base[string trimleft $href /] }
        return $base/[string trimleft $href /]
    }
    if {[string match /* $href]} { return $origin$href }
    # relative to the base path
    if {[string match */ $base]} { return $base$href }
    return [string range $base 0 [string last / $base]]$href
}

# Strip namespace prefixes from element tags so parsing is prefix-agnostic.
proc ::tclutils::tudav::_strip {xml} {
    regsub -all {<(/?)[A-Za-z_][A-Za-z0-9_.-]*:} $xml {<\1} xml
    return $xml
}

# First inner text of <name ...>...</name> (call on prefix-stripped XML).
proc ::tclutils::tudav::_first {xml name} {
    set re "<$name\[^>\]*?>(.*?)</$name>"
    if {[regexp $re $xml -> inner]} {
        return [string trim [::tclutils::tuxml::unescape $inner]]
    }
    return ""
}

# True if <name ...> appears (e.g. a self-closing <collection/>).
proc ::tclutils::tudav::_present {xml name} {
    return [regexp "<$name\[ />\]" $xml]
}

# Parse a DAV multistatus document into a list of resource dicts.
proc ::tclutils::tudav::_parseMultistatus {xml} {
    set xml [_strip $xml]
    set out {}
    foreach {- block} [regexp -all -inline {<response[^>]*?>(.*?)</response>} $xml] {
        set href [_first $block href]
        if {$href eq ""} continue
        set rtype ""
        regexp {<resourcetype[^>]*?>(.*?)</resourcetype>} $block -> rtype
        set status [_first $block status]
        set code ""
        regexp {\s(\d{3})\s} " $status " -> code
        dict set r href $href
        dict set r status $status
        dict set r code $code
        dict set r etag [string trim [_first $block getetag] \"]
        dict set r contenttype [_first $block getcontenttype]
        dict set r displayname [_first $block displayname]
        set data [_first $block calendar-data]
        if {$data eq ""} { set data [_first $block address-data] }
        dict set r data $data
        dict set r collection [_present $rtype collection]
        if {[_present $rtype addressbook]} {
            dict set r kind addressbook
        } elseif {[_present $rtype calendar]} {
            dict set r kind calendar
        } elseif {[dict get $r collection]} {
            dict set r kind collection
        } else {
            dict set r kind ""
        }
        lappend out $r
        unset r
    }
    return $out
}

# Build a PROPFIND body requesting the given properties.
proc ::tclutils::tudav::_propfindBody {props} {
    set inner ""
    foreach p $props { append inner "    <D:$p/>\n" }
    return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<D:propfind\
xmlns:D=\"DAV:\">\n  <D:prop>\n$inner  </D:prop>\n</D:propfind>"
}

# --- client lifecycle ----------------------------------------------------

# Create a client. Options: -user, -password, -headers {k v ...} (extra headers
# sent on every request). Returns a client token.
proc ::tclutils::tudav::client {url args} {
    variable state
    variable seq
    set opts [::tclutils::common::parseOptions \
        {-user "" -password "" -headers {}} {*}$args]
    set c "tudav[incr seq]"
    set state($c) 1
    set state($c,url) $url
    set state($c,headers) [dict get $opts -headers]
    set state($c,auth) ""
    if {[dict get $opts -user] ne ""} {
        set state($c,auth) [_basicAuth [dict get $opts -user] [dict get $opts -password]]
    }
    set state($c,status) ""
    return $c
}

proc ::tclutils::tudav::configure {c args} {
    variable state
    _check $c
    foreach {opt val} $args {
        switch -- $opt {
            -user - -password {
                # recompute combined auth from both
                dict set tmp $opt $val
            }
            -headers { set state($c,headers) $val }
            -url { set state($c,url) $val }
            default {
                return -code error -errorcode {TCLUTILS TUDAV OPTION} \
                    "unknown option: \"$opt\""
            }
        }
    }
    if {[info exists tmp]} {
        # need both user and password; require -user -password together here
        return -code error -errorcode {TCLUTILS TUDAV OPTION} \
            "set credentials via the client command, not configure"
    }
    return
}

proc ::tclutils::tudav::lastStatus {c} {
    variable state
    _check $c
    return $state($c,status)
}

proc ::tclutils::tudav::destroy {c} {
    variable state
    _check $c
    foreach k [array names state $c,*] { unset state($k) }
    unset state($c)
    return
}

# --- request plumbing ----------------------------------------------------

proc ::tclutils::tudav::_ensureTls {url} {
    variable tlsReady
    if {![string match -nocase https://* $url]} return
    if {$tlsReady} return
    if {[catch {package require tls}]} {
        return -code error -errorcode {TCLUTILS TUDAV TLS} \
            "https requires the tls package"
    }
    ::http::register https 443 [list ::tls::socket -autoservername true]
    set tlsReady 1
}

# Perform a request; returns a dict {code ncode body}. Sets lastStatus.
proc ::tclutils::tudav::_request {c method path args} {
    variable state
    _check $c
    set opts [::tclutils::common::parseOptions \
        {-query "" -type "" -depth "" -headers {}} {*}$args]
    set url [_resolve $state($c,url) $path]
    _ensureTls $url

    set hdrs $state($c,headers)
    if {$state($c,auth) ne ""} { lappend hdrs Authorization $state($c,auth) }
    if {[dict get $opts -depth] ne ""} { lappend hdrs Depth [dict get $opts -depth] }
    foreach {k v} [dict get $opts -headers] { lappend hdrs $k $v }

    set cmd [list ::http::geturl $url -method $method -headers $hdrs]
    if {[dict get $opts -query] ne ""} {
        lappend cmd -query [encoding convertto utf-8 [dict get $opts -query]]
        set type [dict get $opts -type]
        if {$type eq ""} { set type "application/xml; charset=utf-8" }
        lappend cmd -type $type
    }
    set tok [{*}$cmd]
    set ncode [::http::ncode $tok]
    set body [::http::data $tok]
    set status [::http::code $tok]
    set meta [::http::meta $tok]
    ::http::cleanup $tok
    set state($c,status) $status
    return [dict create code $status ncode $ncode body $body meta $meta]
}

proc ::tclutils::tudav::_expect {c r okcodes what} {
    set n [dict get $r ncode]
    foreach lo $okcodes { if {$n == $lo} { return } }
    # accept any 2xx if "2xx" requested
    if {"2xx" in $okcodes && $n >= 200 && $n < 300} { return }
    return -code error -errorcode {TCLUTILS TUDAV HTTP} \
        "$what failed: [dict get $r code]"
}

# --- public operations ---------------------------------------------------

# PROPFIND. Options: -path (relative to base, default ""), -depth (default 1),
# -props (default {getetag getcontenttype resourcetype}), -body (raw XML
# overriding -props). Returns a list of resource dicts.
proc ::tclutils::tudav::propfind {c args} {
    set opts [::tclutils::common::parseOptions \
        {-path "" -depth 1 -props {getetag getcontenttype resourcetype} -body ""} \
        {*}$args]
    set body [dict get $opts -body]
    if {$body eq ""} { set body [_propfindBody [dict get $opts -props]] }
    set r [_request $c PROPFIND [dict get $opts -path] \
        -query $body -depth [dict get $opts -depth]]
    _expect $c $r {207} PROPFIND
    return [_parseMultistatus [dict get $r body]]
}

# REPORT (e.g. addressbook-multiget, calendar-query). Returns resource dicts.
proc ::tclutils::tudav::report {c path body args} {
    set opts [::tclutils::common::parseOptions {-depth 1} {*}$args]
    set r [_request $c REPORT $path -query $body -depth [dict get $opts -depth]]
    _expect $c $r {207} REPORT
    return [_parseMultistatus [dict get $r body]]
}

# List the non-collection resources in a collection (PROPFIND depth 1).
# Each entry is a dict: href, etag, contenttype.
proc ::tclutils::tudav::listResources {c args} {
    set opts [::tclutils::common::parseOptions {-path ""} {*}$args]
    set out {}
    foreach res [propfind $c -path [dict get $opts -path] -depth 1] {
        if {[dict get $res collection]} continue
        lappend out [dict create \
            href [dict get $res href] \
            etag [dict get $res etag] \
            contenttype [dict get $res contenttype]]
    }
    return $out
}

# GET a resource; returns the body. Errors on non-2xx.
proc ::tclutils::tudav::get {c path} {
    set r [_request $c GET $path]
    _expect $c $r {2xx} GET
    return [dict get $r body]
}

# PUT a resource. Options: -type (content type), -etag (sent as If-Match).
# Returns the new ETag if the server reports one, else "".
proc ::tclutils::tudav::put {c path data args} {
    set opts [::tclutils::common::parseOptions {-type "text/plain" -etag ""} {*}$args]
    set extra {}
    if {[dict get $opts -etag] ne ""} { lappend extra If-Match [dict get $opts -etag] }
    set r [_request $c PUT $path -query $data -type [dict get $opts -type] -headers $extra]
    _expect $c $r {2xx} PUT
    return [_etagFromMeta $r]
}

# DELETE a resource. Options: -etag (sent as If-Match).
proc ::tclutils::tudav::delete {c path args} {
    set opts [::tclutils::common::parseOptions {-etag ""} {*}$args]
    set extra {}
    if {[dict get $opts -etag] ne ""} { lappend extra If-Match [dict get $opts -etag] }
    set r [_request $c DELETE $path -headers $extra]
    _expect $c $r {2xx} DELETE
    return
}

# --- CalDAV / CardDAV helpers -------------------------------------------

# Format an ISO date/time as CalDAV UTC basic time (YYYYMMDDTHHMMSSZ).
proc ::tclutils::tudav::_caldavTime {iso} {
    set s [string trim $iso]
    if {[string match *Z $s]} { set s [string range $s 0 end-1] }
    foreach fmt {%Y%m%dT%H%M%S %Y-%m-%dT%H:%M:%S %Y%m%d %Y-%m-%d} {
        if {![catch {clock scan $s -format $fmt -gmt 1} e]} {
            return [clock format $e -format %Y%m%dT%H%M%SZ -gmt 1]
        }
    }
    return -code error -errorcode {TCLUTILS TUDAV DATE} "cannot parse date: \"$iso\""
}

# CalDAV calendar-query REPORT for VEVENTs overlapping [fromIso, toIso].
# Returns resource dicts; each one's "data" holds the inline iCalendar text.
proc ::tclutils::tudav::calendarQuery {c path fromIso toIso} {
    set s [_caldavTime $fromIso]
    set e [_caldavTime $toIso]
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<c:calendar-query xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\">
  <d:prop><d:getetag/><c:calendar-data/></d:prop>
  <c:filter><c:comp-filter name=\"VCALENDAR\">
    <c:comp-filter name=\"VEVENT\">
      <c:time-range start=\"$s\" end=\"$e\"/>
    </c:comp-filter></c:comp-filter></c:filter>
</c:calendar-query>"
    return [report $c $path $body -depth 1]
}

# CardDAV addressbook-multiget REPORT for the given hrefs.
# Returns resource dicts; each one's "data" holds the inline vCard text.
proc ::tclutils::tudav::addressbookMultiget {c path hrefs} {
    set hx ""
    foreach h $hrefs { append hx "  <d:href>[::tclutils::tuxml::escape $h]</d:href>\n" }
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<card:addressbook-multiget xmlns:d=\"DAV:\"\
 xmlns:card=\"urn:ietf:params:xml:ns:carddav\">
  <d:prop><d:getetag/><card:address-data/></d:prop>
$hx</card:addressbook-multiget>"
    return [report $c $path $body -depth 1]
}

# Fetch multiple calendar resources by href (CalDAV calendar-multiget REPORT).
# Returns resource dicts; field "data" holds the iCalendar text.
proc ::tclutils::tudav::calendarMultiget {c path hrefs} {
    set hx ""
    foreach h $hrefs { append hx "  <d:href>[::tclutils::tuxml::escape $h]</d:href>\n" }
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<cal:calendar-multiget xmlns:d=\"DAV:\"\
 xmlns:cal=\"urn:ietf:params:xml:ns:caldav\">
  <d:prop><d:getetag/><cal:calendar-data/></d:prop>
$hx</cal:calendar-multiget>"
    return [report $c $path $body -depth 1]
}

# Incremental synchronisation of a collection (RFC 6578 sync-collection REPORT).
# Options: -token (sync-token from a previous call; "" for the initial sync).
# Returns {token <new-sync-token> changes <list of resource dicts>}; each change
# carries href, code and etag (code 404 means the resource was removed).
proc ::tclutils::tudav::syncCollection {c path args} {
    set opts [::tclutils::common::parseOptions {-token ""} {*}$args]
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<d:sync-collection xmlns:d=\"DAV:\">
  <d:sync-token>[::tclutils::tuxml::escape [dict get $opts -token]]</d:sync-token>
  <d:sync-level>1</d:sync-level>
  <d:prop><d:getetag/></d:prop>
</d:sync-collection>"
    set r [_request $c REPORT $path -query $body]
    _expect $c $r {2xx} sync-collection
    return [dict create \
        token   [_syncToken [dict get $r body]] \
        changes [_parseMultistatus [dict get $r body]]]
}

proc ::tclutils::tudav::_syncToken {xml} {
    set xml [_strip $xml]
    set tok ""
    regexp {<sync-token[^>]*>(.*?)</sync-token>} $xml -> tok
    return [string trim $tok]
}

# Pull the (quote-stripped) ETag out of a response's headers, or "".
proc ::tclutils::tudav::_etagFromMeta {r} {
    if {![dict exists $r meta]} { return "" }
    foreach {k v} [dict get $r meta] {
        if {[string equal -nocase $k etag]} { return [string trim $v \"] }
    }
    return ""
}

# --- discovery (RFC 5397 / 6764) ---------------------------------------

# Extract the <href> contained in a named element of a multistatus body.
proc ::tclutils::tudav::_hrefIn {xml element} {
    set xml [_strip $xml]
    if {[regexp "<$element\[^>\]*?>(.*?)</$element>" $xml -> inner]} {
        return [_first $inner href]
    }
    return ""
}

# DAV:current-user-principal of the authenticated user (PROPFIND Depth 0).
# Returns the principal href (e.g. /alice/) or "".
proc ::tclutils::tudav::currentUserPrincipal {c args} {
    set opts [::tclutils::common::parseOptions {-path ""} {*}$args]
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<D:propfind xmlns:D=\"DAV:\"><D:prop><D:current-user-principal/></D:prop></D:propfind>"
    set r [_request $c PROPFIND [dict get $opts -path] -query $body -depth 0]
    _expect $c $r {207} current-user-principal
    return [_hrefIn [dict get $r body] current-user-principal]
}

# CalDAV calendar-home-set of a principal (PROPFIND Depth 0). Returns href or "".
proc ::tclutils::tudav::calendarHomeSet {c path} {
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<D:propfind xmlns:D=\"DAV:\" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">\
<D:prop><C:calendar-home-set/></D:prop></D:propfind>"
    set r [_request $c PROPFIND $path -query $body -depth 0]
    _expect $c $r {207} calendar-home-set
    return [_hrefIn [dict get $r body] calendar-home-set]
}

# CardDAV addressbook-home-set of a principal (PROPFIND Depth 0). href or "".
proc ::tclutils::tudav::addressbookHomeSet {c path} {
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<D:propfind xmlns:D=\"DAV:\" xmlns:C=\"urn:ietf:params:xml:ns:carddav\">\
<D:prop><C:addressbook-home-set/></D:prop></D:propfind>"
    set r [_request $c PROPFIND $path -query $body -depth 0]
    _expect $c $r {207} addressbook-home-set
    return [_hrefIn [dict get $r body] addressbook-home-set]
}

# Best-effort RFC 6764 bootstrap: the redirect target of /.well-known/<type>
# (type = caldav | carddav), or "" if the server does not provide it.
proc ::tclutils::tudav::wellKnown {c type} {
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<D:propfind xmlns:D=\"DAV:\"><D:prop><D:current-user-principal/></D:prop></D:propfind>"
    set r [_request $c PROPFIND /.well-known/$type -query $body -depth 0]
    set n [dict get $r ncode]
    if {$n >= 300 && $n < 400} {
        foreach {k v} [dict get $r meta] {
            if {[string equal -nocase $k location]} { return $v }
        }
    }
    return ""
}

# Convenience: principal + both home-sets in one dict.
# Returns {principal <href> calendarHome <href> addressbookHome <href>}.
proc ::tclutils::tudav::discover {c args} {
    set opts [::tclutils::common::parseOptions {-path ""} {*}$args]
    set principal [currentUserPrincipal $c -path [dict get $opts -path]]
    set cal ""
    set adr ""
    if {$principal ne ""} {
        catch {set cal [calendarHomeSet $c $principal]}
        catch {set adr [addressbookHomeSet $c $principal]}
    }
    return [dict create principal $principal calendarHome $cal addressbookHome $adr]
}

# --- collection properties (PROPPATCH / PROPFIND) ----------------------

# short name -> {xmlns-prefix element}. The namespace prefixes are declared by
# _propNsDecl. "supported-calendar-component-set" is read-only (set at create).
proc ::tclutils::tudav::_propRegistry {} {
    return {
        displayname                      {D displayname}
        calendar-color                   {I calendar-color}
        calendar-description             {C calendar-description}
        addressbook-description          {CR addressbook-description}
        supported-calendar-component-set {C supported-calendar-component-set}
    }
}
proc ::tclutils::tudav::_propNsDecl {} {
    return {xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:CR="urn:ietf:params:xml:ns:carddav" xmlns:I="http://apple.com/ns/ical/"}
}

# Set collection properties (PROPPATCH). $props is a dict of short-name -> value;
# supported names: displayname, calendar-color (#rrggbb[aa]), calendar-description,
# addressbook-description. Errors {TCLUTILS TUDAV PROP} on an unsettable name.
proc ::tclutils::tudav::proppatch {c path props} {
    set reg [_propRegistry]
    set inner ""
    dict for {k v} $props {
        if {$k eq "supported-calendar-component-set" || ![dict exists $reg $k]} {
            return -code error -errorcode {TCLUTILS TUDAV PROP} \
                "cannot set property \"$k\""
        }
        lassign [dict get $reg $k] pfx el
        append inner "      <$pfx:$el>[::tclutils::tuxml::escape $v]</$pfx:$el>\n"
    }
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<D:propertyupdate [_propNsDecl]>
  <D:set>
    <D:prop>
$inner    </D:prop>
  </D:set>
</D:propertyupdate>"
    set r [_request $c PROPPATCH $path -query $body]
    _expect $c $r {2xx} PROPPATCH
    return ""
}

# Read collection properties (PROPFIND Depth 0). Returns a dict of short-name ->
# value; supported-calendar-component-set yields a list of component names.
proc ::tclutils::tudav::getProperties {c args} {
    set opts [::tclutils::common::parseOptions \
        {-path "" -props {displayname calendar-color calendar-description
                          addressbook-description supported-calendar-component-set}} {*}$args]
    set reg [_propRegistry]
    set inner ""
    foreach k [dict get $opts -props] {
        if {![dict exists $reg $k]} {
            return -code error -errorcode {TCLUTILS TUDAV PROP} \
                "unknown property \"$k\""
        }
        lassign [dict get $reg $k] pfx el
        append inner "    <$pfx:$el/>\n"
    }
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<D:propfind [_propNsDecl]>
  <D:prop>
$inner  </D:prop>
</D:propfind>"
    set r [_request $c PROPFIND [dict get $opts -path] -query $body -depth 0]
    _expect $c $r {207} PROPFIND
    set xml [_strip [dict get $r body]]
    set out [dict create]
    foreach k [dict get $opts -props] {
        if {$k eq "supported-calendar-component-set"} {
            set comps {}
            foreach {_ name} [regexp -all -inline {<comp name="([^"]+)"} $xml] {
                lappend comps $name
            }
            dict set out $k $comps
        } else {
            lassign [dict get $reg $k] pfx el
            dict set out $k [_first $xml $el]
        }
    }
    return $out
}

# --- collection provisioning -------------------------------------------

# List the child collections of $path (address books, calendars, plain
# collections). Returns dicts {href displayname kind}; the queried collection
# itself is excluded. Useful for discovering what exists under a principal,
# e.g. listCollections $c -path /alice/ .
proc ::tclutils::tudav::listCollections {c args} {
    set opts [::tclutils::common::parseOptions {-path ""} {*}$args]
    set p [dict get $opts -path]
    set out {}
    foreach res [propfind $c -path $p -depth 1 -props {resourcetype displayname}] {
        if {![dict get $res collection]} continue
        if {[string trimright [dict get $res href] /] eq [string trimright $p /]} continue
        lappend out [dict create \
            href [dict get $res href] \
            displayname [dict get $res displayname] \
            kind [dict get $res kind]]
    }
    return $out
}


# Create a plain WebDAV collection at $path (RFC 5689 extended MKCOL).
# Option: -displayname.
proc ::tclutils::tudav::mkCollection {c path args} {
    set opts [::tclutils::common::parseOptions {-displayname ""} {*}$args]
    return [_mkcolExtended $c $path "" [dict get $opts -displayname]]
}

# Create a CardDAV address book collection at $path. Option: -displayname.
proc ::tclutils::tudav::mkAddressbook {c path args} {
    set opts [::tclutils::common::parseOptions {-displayname ""} {*}$args]
    return [_mkcolExtended $c $path carddav [dict get $opts -displayname]]
}

# Create a CalDAV calendar collection at $path (RFC 4791 MKCALENDAR).
# Option: -displayname.
proc ::tclutils::tudav::mkCalendar {c path args} {
    set opts [::tclutils::common::parseOptions {-displayname ""} {*}$args]
    set dn [dict get $opts -displayname]
    set props ""
    if {$dn ne ""} {
        append props "<D:displayname>[::tclutils::tuxml::escape $dn]</D:displayname>"
    }
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>\
<C:mkcalendar xmlns:D=\"DAV:\" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">\
<D:set><D:prop>$props</D:prop></D:set></C:mkcalendar>"
    set r [_request $c MKCALENDAR $path -query $body -type {application/xml; charset=utf-8}]
    _expect $c $r {2xx} MKCALENDAR
    return ""
}

# Build and send an extended-MKCOL request. kind: "" (plain), carddav, caldav.
proc ::tclutils::tudav::_mkcolExtended {c path kind displayname} {
    set ns ""
    set rt ""
    switch -- $kind {
        carddav { set ns " xmlns:C=\"urn:ietf:params:xml:ns:carddav\""; set rt "<C:addressbook/>" }
        caldav  { set ns " xmlns:C=\"urn:ietf:params:xml:ns:caldav\"";  set rt "<C:calendar/>" }
    }
    set props "<D:resourcetype><D:collection/>$rt</D:resourcetype>"
    if {$displayname ne ""} {
        append props "<D:displayname>[::tclutils::tuxml::escape $displayname]</D:displayname>"
    }
    set body "<?xml version=\"1.0\" encoding=\"utf-8\"?>\
<D:mkcol xmlns:D=\"DAV:\"$ns><D:set><D:prop>$props</D:prop></D:set></D:mkcol>"
    set r [_request $c MKCOL $path -query $body -type {application/xml; charset=utf-8}]
    _expect $c $r {2xx} MKCOL
    return ""
}

package provide tclutils::tudav 0.1
