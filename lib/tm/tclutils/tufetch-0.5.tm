# tclutils::tufetch -- tiny HTTP(S) helper: GET/POST into memory or to a file.
# Description: tiny HTTP(S) helper: GET/POST into memory or to a file.
# Category: Network · web
# Tcl 8.6+ and 9.x.
#
# Retrieves a URL (get -> text, download -> file), byte-safe. Transport order:
#   1) native Tcl  http + tls   (tls loaded lazily, like tclutils::tudav)
#   2) fallback     curl / wget (located via auto_execok)
#
# 0.2 added request control used by higher-level modules (e.g. tusparql):
#   -method get|post   -headers {k v k v ...}   -data <body>   -type <content-type>
#
# 0.3 adds a structured error taxonomy modelled on the www package, so callers
# can match at the granularity they need with try/trap (errorcodes are prefix-
# matched):
#   {TCLUTILS TUFETCH HTTP <class> <code>}   e.g. {... HTTP 4XX 404}, {... HTTP 5XX 503}
#   {TCLUTILS TUFETCH URL}                   unsupported/invalid URL
#   {TCLUTILS TUFETCH TIMEOUT}               the request timed out
#   {TCLUTILS TUFETCH CONNECT}               connection/DNS/transport failure
#   {TCLUTILS TUFETCH REDIRECT}              too many redirects
#   {TCLUTILS TUFETCH NOMETHOD}              no transport available
# so e.g. `trap {TCLUTILS TUFETCH HTTP 4XX 404}` catches just 404,
# `trap {TCLUTILS TUFETCH HTTP 4XX}` any client error, `trap {TCLUTILS TUFETCH
# HTTP}` any status error, and `trap {TCLUTILS TUFETCH}` anything from tufetch.
# The status-class and transport classification live in pure helpers
# (_httpClass/_statusReason/_curlExitReason), so the taxonomy is tested without
# a network. NOTE: the HTTP errorcode gained a <class> element in 0.3, so code
# that trapped the old 3-element {TCLUTILS TUFETCH HTTP <code>} exactly must use
# the prefix {TCLUTILS TUFETCH HTTP} (prefix traps were unaffected).
#
# 0.4 verifies server certificates on every transport. Up to 0.3 the native
# path registered https GLOBALLY with -require 0: after one tufetch call every
# ::http::geturl https://... in the process accepted any certificate, while the
# curl/wget paths did verify -- the same URL passed or failed depending on the
# transport. Now:
#   - the native path uses tclutils::tuhttps: verifying socket, https
#     registered only for the duration of the request, previous registration
#     restored afterwards;
#   - -cafile <file> verifies against that CA bundle (all transports);
#   - -insecure 1 accepts any certificate (all transports: curl -k, wget
#     --no-check-certificate). Never the default.
#   - tls 1.x (Tcl 8.6) cannot find the system CA store; without a CA bundle
#     the native path steps aside and curl/wget are tried. If neither exists,
#     NOMETHOD names the way out instead of fetching unverified.
#
# 0.5 checks each redirect: a relative Location is resolved against the
# current URL (up to 0.4 it went to http::geturl as it was and failed), the
# target must be http or https, and a redirect from https to http is
# {TCLUTILS TUFETCH REDIRECT}. curl gets --proto-redir to the same effect;
# wget has no such switch. The native path writes the file through a
# temporary file: an error while writing leaves the old file.
#
# This module is NOT dependency-free: it uses the core http package and either
# the tls extension or an external curl/wget. It is meant as an optional helper.

package require Tcl 8.6-
package require tclutils::common 0.3
package require tclutils::tuhttps 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tufetch {
    namespace export get download
    variable version 0.5
    variable defaults {-timeout 30000 -redirects 5 -method GET -headers {} -data {} -type {}
                       -insecure 0 -cafile {}}
    # why the native path stepped aside (for the NOMETHOD message), or ""
    variable nativeSkipped ""
}

# get url ?opts? -- return the body as UTF-8 text.
proc ::tclutils::tufetch::get {url args} {
    set tmp [file join [_tmpdir] tufetch-[pid]-[clock clicks -milliseconds].tmp]
    try {
        download $url $tmp {*}$args
        set fh [open $tmp rb]
        set bytes [read $fh]
        close $fh
        return [encoding convertfrom utf-8 $bytes]
    } finally {
        file delete -force -- $tmp
    }
}

# download url path ?opts? -- save URL to path (raw bytes).
# Options: -timeout ms, -redirects n, -method get|post, -headers {k v ...},
#          -data <body>, -type <content-type>, -cafile <CA bundle>,
#          -insecure 0|1 (accept any certificate; default 0).
# Returns the transport used: native | curl | wget.
proc ::tclutils::tufetch::download {url path args} {
    variable defaults
    _checkUrl $url
    variable nativeSkipped
    set o [::tclutils::common::parseOptions $defaults {*}$args]
    dict set o -insecure [::tclutils::common::ensureBoolean [dict get $o -insecure] -insecure]
    set nativeSkipped ""
    if {[_native $url $path $o]} { return native }
    set curl [auto_execok curl]
    if {$curl ne ""} {
        if {[catch {exec {*}$curl {*}[_curlArgs $url $path $o]} out copts]} {
            catch {file delete -force -- $path}
            set ec [dict get $copts -errorcode]
            set reason CONNECT
            if {[lindex $ec 0] eq "CHILDSTATUS"} {
                set reason [_curlExitReason [lindex $ec 2]]
            }
            return -code error -errorcode [list TCLUTILS TUFETCH $reason] \
                "curl could not fetch $url: [string trim $out]"
        }
        set code [string trim $out]
        if {![string is integer -strict $code] || $code < 200 || $code >= 300} {
            catch {file delete -force -- $path}
            _httpError $code $url
        }
        return curl
    }
    set wget [auto_execok wget]
    if {$wget ne ""} {
        exec {*}$wget {*}[_wgetArgs $url $path $o]
        return wget
    }
    set msg "no HTTP method available -- install the Tcl tls package or curl/wget"
    if {$nativeSkipped ne ""} { set msg "no HTTP method available: $nativeSkipped" }
    return -code error -errorcode {TCLUTILS TUFETCH NOMETHOD} $msg
}

# --- error taxonomy (pure helpers, network-free) -----------------------------

# _httpClass code -- "4XX"/"5XX"/... for 100..599, else "" (defensive).
proc ::tclutils::tufetch::_httpClass {code} {
    if {![string is integer -strict $code]} { return "" }
    if {$code < 100 || $code > 599} { return "" }
    return [expr {$code / 100}]XX
}

# _httpError ncode url -- raise {TCLUTILS TUFETCH HTTP <class> <code>}.
proc ::tclutils::tufetch::_httpError {ncode url} {
    set cls [_httpClass $ncode]
    if {$cls eq ""} { set cls XXX }
    return -code error -errorcode [list TCLUTILS TUFETCH HTTP $cls $ncode] \
        "HTTP $ncode for $url"
}

# _statusReason status -- map a non-"ok" ::http status to a reason word.
proc ::tclutils::tufetch::_statusReason {status} {
    switch -- $status {
        timeout { return TIMEOUT }
        default { return CONNECT }
    }
}

# _curlExitReason code -- map a curl exit code to a reason word.
# (28 = operation timeout; 6/7 = could not resolve/connect; rest -> CONNECT.)
proc ::tclutils::tufetch::_curlExitReason {code} {
    switch -- $code {
        28 { return TIMEOUT }
        default { return CONNECT }
    }
}

# _checkUrl url -- accept only http/https; otherwise {TCLUTILS TUFETCH URL}.
proc ::tclutils::tufetch::_checkUrl {url} {
    if {![regexp -nocase {^https?://} $url]} {
        return -code error -errorcode {TCLUTILS TUFETCH URL} \
            "unsupported or invalid URL: $url"
    }
}

# _redirectUrl from loc -- the absolute target of a Location header, checked.
# Pure helper. Relative forms: "//host/p", "/p", "p", "?q".
# Remove "." and ".." segments from a URL path; ".." never climbs above
# the root.
proc ::tclutils::tufetch::_dotSegments {path} {
    set out {}
    set segs [split $path /]
    set n [llength $segs]
    for {set i 0} {$i < $n} {incr i} {
        set s [lindex $segs $i]
        set last [expr {$i == $n - 1}]
        switch -- $s {
            . { if {$last} { lappend out "" } }
            .. {
                if {[llength $out] > 1} { set out [lrange $out 0 end-1] }
                if {$last} { lappend out "" }
            }
            default { lappend out $s }
        }
    }
    return [join $out /]
}

proc ::tclutils::tufetch::_redirectUrl {from loc} {
    set loc [string trim $loc]
    regexp {^([a-zA-Z][a-zA-Z0-9+.-]*):} $from -> scheme
    regexp {^([a-zA-Z][a-zA-Z0-9+.-]*://[^/?#]*)([^?#]*)} $from -> origin path
    if {[regexp {^[a-zA-Z][a-zA-Z0-9+.-]*:} $loc]} {
        set to $loc
    } elseif {[string match //* $loc]} {
        set to $scheme:$loc
    } elseif {[string match /* $loc]} {
        set to $origin$loc
    } elseif {[string index $loc 0] eq "?"} {
        set to $origin$path$loc
    } elseif {$path eq ""} {
        set to $origin/$loc
    } else {
        set to $origin[string range $path 0 [string last / $path]]$loc
    }
    if {![regexp -nocase {^https?://} $to]} {
        return -code error -errorcode {TCLUTILS TUFETCH REDIRECT} \
            "redirect to an unsupported URL: $to"
    }
    # "." and ".." in the path are resolved (RFC 3986 5.2.4)
    if {[regexp {^([a-zA-Z][a-zA-Z0-9+.-]*://[^/?#]*)([^?#]*)(.*)$} $to -> o p rest]} {
        set to $o[_dotSegments $p]$rest
    }
    if {[string equal -nocase $scheme https] && [regexp -nocase {^http://} $to]} {
        return -code error -errorcode {TCLUTILS TUFETCH REDIRECT} \
            "redirect from https to http refused: $to"
    }
    return $to
}

# --- request-line construction (pure helpers) --------------------------------

# _nativeOpts o timeout -- build the ::http::geturl option list. Pure helper.
proc ::tclutils::tufetch::_nativeOpts {o timeout} {
    set opts [list -binary 1 -timeout $timeout]
    set headers [dict get $o -headers]
    if {[llength $headers]} { lappend opts -headers $headers }
    set data [dict get $o -data]
    if {$data ne ""} {
        lappend opts -query $data
        if {[dict get $o -type] ne ""} { lappend opts -type [dict get $o -type] }
    }
    set m [string toupper [dict get $o -method]]
    if {$m ne "GET"} { lappend opts -method $m }
    return $opts
}

# _curlArgs url path o -- build the curl argument list. Pure helper.
proc ::tclutils::tufetch::_curlArgs {url path o} {
    set a [list -sS -L -o $path -w {%{http_code}} \
        --retry 2 --max-redirs [dict get $o -redirects] \
        --max-time [expr {[dict get $o -timeout] / 1000}]]
    lappend a -X [string toupper [dict get $o -method]]
    # redirects: only http(s), and from https only to https
    if {[string match -nocase https:* $url]} {
        lappend a --proto-redir =https
    } else {
        lappend a --proto-redir =http,https
    }
    if {[dict exists $o -insecure] && [dict get $o -insecure]} { lappend a -k }
    if {[dict exists $o -cafile] && [dict get $o -cafile] ne ""} {
        lappend a --cacert [dict get $o -cafile]
    }
    foreach {k v} [dict get $o -headers] { lappend a -H "$k: $v" }
    if {[dict get $o -type] ne ""} { lappend a -H "Content-Type: [dict get $o -type]" }
    if {[dict get $o -data] ne ""} { lappend a --data-binary [dict get $o -data] }
    lappend a -- $url
    return $a
}

# _wgetArgs url path o -- build the wget argument list. Pure helper.
# (wget is the rough fallback; it does not translate HTTP status into an
#  errorcode -- a 4xx/5xx surfaces as a CHILDSTATUS from exec.)
proc ::tclutils::tufetch::_wgetArgs {url path o} {
    set a [list -q -O $path --tries=2 \
        --timeout=[expr {[dict get $o -timeout] / 1000}]]
    set m [string toupper [dict get $o -method]]
    if {$m ne "GET"} { lappend a --method=$m }
    if {[dict exists $o -insecure] && [dict get $o -insecure]} { lappend a --no-check-certificate }
    if {[dict exists $o -cafile] && [dict get $o -cafile] ne ""} {
        lappend a --ca-certificate=[dict get $o -cafile]
    }
    # one argument per header: "--header=Name: value" (up to 0.3 the value
    # became a separate argument, which wget read as a second URL)
    foreach {k v} [dict get $o -headers] { lappend a "--header=$k: $v" }
    if {[dict get $o -type] ne ""} { lappend a "--header=Content-Type: [dict get $o -type]" }
    if {[dict get $o -data] ne ""} { lappend a --body-data=[dict get $o -data] }
    lappend a -- $url
    return $a
}

# _native -- pure-Tcl http+tls path. Returns 1 on success, 0 if http/tls absent
# or (tls 1.x) no CA bundle is available for verification.
proc ::tclutils::tufetch::_native {url path o} {
    variable nativeSkipped
    if {[catch {package require http}]} { return 0 }
    if {![string match -nocase https:* $url]} {
        return [_nativeLoop $url $path $o]
    }
    set host ""
    regexp -nocase {^https://(\[[^\]]+\]|[^/:]+)} $url -> host
    set sopts [list -host $host -insecure [dict get $o -insecure]]
    if {[dict get $o -cafile] ne ""} { lappend sopts -cafile [dict get $o -cafile] }
    try {
        set prefix [::tclutils::tuhttps::socketCmd {*}$sopts]
    } trap {TCLUTILS TUHTTPS NOTLS} {} {
        return 0
    } trap {TCLUTILS TUHTTPS NOCA} {msg} {
        set nativeSkipped $msg
        return 0
    } trap {TCLUTILS TUHTTPS CAFILE} {msg} {
        return -code error -errorcode {TCLUTILS TUFETCH CAFILE} $msg
    }
    return [::tclutils::tuhttps::with $prefix [list [namespace current]::_nativeLoop $url $path $o]]
}

# _nativeLoop -- the request/redirect loop over ::http::geturl. Returns 1.
proc ::tclutils::tufetch::_nativeLoop {url path o} {
    set timeout   [dict get $o -timeout]
    set redirects [dict get $o -redirects]
    set hops 0
    while {1} {
        if {[catch {::http::geturl $url {*}[_nativeOpts $o $timeout]} tok]} {
            set msg "cannot connect to $url: $tok"
            if {[string match -nocase https:* $url] && ![dict get $o -insecure]} {
                append msg " (if the server certificate is self-signed or from an\
                    internal CA: -cafile <file>; -insecure 1 only for a trusted\
                    internal server)"
            }
            return -code error -errorcode {TCLUTILS TUFETCH CONNECT} $msg
        }
        try {
            set status [::http::status $tok]
            if {$status ne "ok"} {
                return -code error \
                    -errorcode [list TCLUTILS TUFETCH [_statusReason $status]] \
                    "$status while fetching $url"
            }
            set ncode [::http::ncode $tok]
            if {$ncode in {301 302 303 307 308}} {
                upvar #0 $tok state
                set loc ""
                foreach {k v} $state(meta) {
                    if {[string equal -nocase $k location]} { set loc $v }
                }
                if {$loc eq "" || [incr hops] > $redirects} {
                    return -code error -errorcode {TCLUTILS TUFETCH REDIRECT} \
                        "too many redirects for $url"
                }
                set next [_redirectUrl $url $loc]
                if {[string match -nocase https:* $next]
                        && ![string match -nocase https:* $url]} {
                    # http -> https: the tls socket is set up in _native
                    dict set o -redirects [expr {$redirects - $hops}]
                    return [_native $next $path $o]
                }
                set url $next
                continue
            }
            if {$ncode != 200} { _httpError $ncode $url }
            ::tclutils::common::replaceFile $path [::http::data $tok] -encoding binary
            return 1
        } finally {
            ::http::cleanup $tok
        }
    }
}

# _tmpdir -- a writable temp directory (honours TMPDIR/TEMP/TMP, else /tmp/cwd).
proc ::tclutils::tufetch::_tmpdir {} {
    foreach v {TMPDIR TEMP TMP} {
        if {[info exists ::env($v)] && [file isdirectory $::env($v)]} {
            return $::env($v)
        }
    }
    if {[file isdirectory /tmp]} {
        return "/tmp"
    }
    return [pwd]
}

package provide tclutils::tufetch 0.5
