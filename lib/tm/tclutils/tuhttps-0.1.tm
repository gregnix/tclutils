# tclutils::tuhttps -- one place for the HTTPS policy of the http+tls modules
# Description: verifying tls socket command and scoped https registration
# Category: Network · web
# Tcl 8.6+ and 9.x.
#
# Why this module exists
# ----------------------
# ::http::register is GLOBAL to the interpreter. Before tclutils 0.63.0,
# tufetch, tudav and tupostgrest each registered "https" themselves, with three
# different policies, and never undid it. Whoever registered last decided for
# everybody: one call to tufetch (which used -require 0) left every later
# ::http::geturl https://... in the process without certificate verification --
# measured 2026-09-19 against a self-signed local server.
#
# This module gives the three one rule:
#   socketCmd  builds the ::tls::socket prefix. It VERIFIES by default; only
#              -insecure 1 turns verification off, and only for that command.
#   with       registers https with such a prefix for the duration of a script
#              and restores the previous registration afterwards, also on error.
#
# tls 1.x (the usual package on Tcl 8.6) does not find the system CA store by
# itself: with -require 1 and no -cafile every real HTTPS request fails. So for
# tls < 2.0 socketCmd looks for a CA bundle file (SSL_CERT_FILE, then the usual
# Linux/BSD/macOS locations). If none is found it raises NOCA with the way out
# in the message -- it does not quietly fall back to "no verification".
# tls 2.0 (Tcl 9) uses the OpenSSL default paths and needs no file.
#
# What this module does NOT see: a caller that registers https itself after us,
# or asynchronous ::http::geturl -command requests started by the application
# while a `with` script runs. The registration is scoped, not locked.

package require Tcl 8.6-
package require tclutils::common 0.2

namespace eval ::tclutils {}
namespace eval ::tclutils::tuhttps {
    namespace export socketCmd caFile with
    variable version 0.1
    # Candidate CA bundles for tls < 2.0, in order. SSL_CERT_FILE is checked
    # before these (see caFile).
    variable caCandidates {
        /etc/ssl/certs/ca-certificates.crt
        /etc/pki/tls/certs/ca-bundle.crt
        /etc/ssl/ca-bundle.pem
        /etc/ssl/cert.pem
        /usr/local/etc/openssl/cert.pem
    }
}

# caFile -- the CA bundle tls 1.x should use, or "" if none is found.
# SSL_CERT_FILE wins when it names a readable file.
proc ::tclutils::tuhttps::caFile {} {
    variable caCandidates
    set list $caCandidates
    if {[info exists ::env(SSL_CERT_FILE)]} {
        set list [linsert $list 0 $::env(SSL_CERT_FILE)]
    }
    foreach f $list {
        if {$f ne "" && [file isfile $f] && [file readable $f]} { return $f }
    }
    return ""
}

# _isIpHost host -- 1 for an IPv4/IPv6 literal (no SNI for those).
proc ::tclutils::tuhttps::_isIpHost {host} {
    set host [string trim $host {[]}]
    return [expr {[regexp {^\d{1,3}(\.\d{1,3}){3}$} $host] || [string match *:* $host]}]
}

# socketCmd ?-insecure 0|1? ?-cafile path? ?-host name?
# Returns a command prefix for ::http::register https 443 <prefix>.
#   -insecure 1   accept any certificate (self-signed internal server). Never
#                 the default.
#   -cafile path  verify against this CA bundle (overrides the search).
#   -host name    host of the request; an IP literal gets no SNI, because some
#                 tls builds reject an IP as SNI name ("failed to use socket").
# Errors: {TCLUTILS TUHTTPS NOTLS}  tls package not available
#         {TCLUTILS TUHTTPS CAFILE} -cafile not readable
#         {TCLUTILS TUHTTPS NOCA}   tls < 2.0 and no CA bundle found
proc ::tclutils::tuhttps::socketCmd {args} {
    set o [::tclutils::common::parseOptions {-insecure 0 -cafile "" -host ""} {*}$args]
    set insecure [::tclutils::common::ensureBoolean [dict get $o -insecure] -insecure]
    if {[catch {package require tls} err]} {
        return -code error -errorcode {TCLUTILS TUHTTPS NOTLS} \
            "https needs the tls package: $err"
    }
    set sni [expr {[_isIpHost [dict get $o -host]] ? 0 : 1}]
    set cmd [list ::tls::socket -autoservername $sni]
    if {$insecure} {
        return [concat $cmd -request 0 -require 0]
    }
    set ca [dict get $o -cafile]
    if {$ca ne ""} {
        if {![file isfile $ca] || ![file readable $ca]} {
            return -code error -errorcode {TCLUTILS TUHTTPS CAFILE} \
                "cannot read CA file: $ca"
        }
        return [concat $cmd -require 1 -cafile [list $ca]]
    }
    if {[package vcompare [package provide tls] 2.0] >= 0} {
        return [concat $cmd -require 1]
    }
    set ca [caFile]
    if {$ca eq ""} {
        return -code error -errorcode {TCLUTILS TUHTTPS NOCA} \
            "tls [package provide tls] cannot verify certificates without a CA\
bundle, and none was found. Pass -cafile <file> or set SSL_CERT_FILE;\
use -insecure 1 only for a trusted internal server."
    }
    return [concat $cmd -require 1 -cafile [list $ca]]
}

# with prefix script -- run SCRIPT (in the caller's frame) with https
# registered to PREFIX; afterwards the previous https registration is restored
# (or removed, if there was none), also when SCRIPT raises an error.
# Returns the result of SCRIPT. Do not use `return` inside SCRIPT.
proc ::tclutils::tuhttps::with {prefix script} {
    package require http
    set had [info exists ::http::urlTypes(https)]
    if {$had} { set old $::http::urlTypes(https) }
    ::http::register https 443 $prefix
    try {
        return [uplevel 1 $script]
    } finally {
        if {$had} {
            set ::http::urlTypes(https) $old
        } else {
            catch {::http::unregister https}
        }
    }
}

package provide tclutils::tuhttps 0.1
