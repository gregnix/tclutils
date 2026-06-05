# tclutils::tufetch -- tiny HTTP(S) helper: GET/POST into memory or to a file.
# Tcl 8.6+ and 9.x.
#
# Retrieves a URL (get -> text, download -> file), byte-safe. Transport order:
#   1) native Tcl  http + tls   (tls loaded lazily, like tclutils::tudav)
#   2) fallback     curl / wget (located via auto_execok)
#
# 0.2 adds request control used by higher-level modules (e.g. tusparql):
#   -method get|post   -headers {k v k v ...}   -data <body>   -type <content-type>
# The curl path now reports HTTP errors as {TCLUTILS TUFETCH HTTP <code>} (same
# errorcode as the native path), instead of a raw CHILDSTATUS. The request-line
# construction lives in pure helpers (_nativeOpts/_curlArgs/_wgetArgs) so it can
# be tested without a network.
#
# This module is NOT dependency-free: it uses the core http package and either
# the tls extension or an external curl/wget. It is meant as an optional helper.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tufetch {
    namespace export get download
    variable version 0.2
    variable defaults {-timeout 30000 -redirects 5 -method GET -headers {} -data {} -type {}}
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
#          -data <body>, -type <content-type>.
# Returns the transport used: native | curl | wget.
proc ::tclutils::tufetch::download {url path args} {
    variable defaults
    set o [::tclutils::common::parseOptions $defaults {*}$args]
    if {[_native $url $path $o]} { return native }
    set curl [auto_execok curl]
    if {$curl ne ""} {
        set code [string trim [exec {*}$curl {*}[_curlArgs $url $path $o]]]
        if {![string is integer -strict $code] || $code < 200 || $code >= 300} {
            catch {file delete -force -- $path}
            return -code error -errorcode [list TCLUTILS TUFETCH HTTP $code] \
                "HTTP $code for $url"
        }
        return curl
    }
    set wget [auto_execok wget]
    if {$wget ne ""} {
        exec {*}$wget {*}[_wgetArgs $url $path $o]
        return wget
    }
    return -code error -errorcode {TCLUTILS TUFETCH NOMETHOD} \
        "no HTTP method available -- install the Tcl tls package or curl/wget"
}

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
    foreach {k v} [dict get $o -headers] { lappend a --header=$k: $v }
    if {[dict get $o -type] ne ""} { lappend a --header=Content-Type: [dict get $o -type] }
    if {[dict get $o -data] ne ""} { lappend a --body-data=[dict get $o -data] }
    lappend a -- $url
    return $a
}

# _native -- pure-Tcl http+tls path. Returns 1 on success, 0 if http/tls absent.
proc ::tclutils::tufetch::_native {url path o} {
    if {[catch {package require http}]} { return 0 }
    if {[string match -nocase https:* $url] && [catch {package require tls}]} {
        return 0
    }
    catch {::http::register https 443 [list ::tls::socket -autoservername 1 -require 0]}
    set timeout   [dict get $o -timeout]
    set redirects [dict get $o -redirects]
    set hops 0
    while {1} {
        set tok [::http::geturl $url {*}[_nativeOpts $o $timeout]]
        try {
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
                set url $loc
                continue
            }
            if {[::http::status $tok] ne "ok" || $ncode != 200} {
                return -code error -errorcode [list TCLUTILS TUFETCH HTTP $ncode] \
                    "HTTP $ncode for $url"
            }
            set fh [open $path wb]
            puts -nonewline $fh [::http::data $tok]
            close $fh
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
    return [expr {[file isdirectory /tmp] ? "/tmp" : [pwd]}]
}

package provide tclutils::tufetch 0.2
