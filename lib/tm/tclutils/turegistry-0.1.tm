# tclutils::turegistry -- a small keyed value registry (service locator / bag).
# Create independent registries, store values under keys, and fetch them with a
# required-get that errors on a missing key (or returns a supplied default).
# Pure Tcl. Tcl 8.6+ and 9.x.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::turegistry {
    namespace export create put get has keys remove destroy
    variable state
    variable seq 0
}

proc ::tclutils::turegistry::_check {reg} {
    variable state
    if {![info exists state($reg)]} {
        return -code error -errorcode {TCLUTILS TUREGISTRY REG} \
            "unknown registry: \"$reg\""
    }
}

# Create a new registry; returns its token.
proc ::tclutils::turegistry::create {} {
    variable state
    variable seq
    set reg "turegistry[incr seq]"
    set state($reg) 1
    return $reg
}

# Store a value under a key; returns the value.
proc ::tclutils::turegistry::put {reg key value} {
    variable state
    _check $reg
    set state($reg,k,$key) $value
    return $value
}

# Fetch a value. Without a default, a missing key errors
# {TCLUTILS TUREGISTRY KEY}; with a default, the default is returned instead.
proc ::tclutils::turegistry::get {reg key args} {
    variable state
    _check $reg
    if {[info exists state($reg,k,$key)]} { return $state($reg,k,$key) }
    if {[llength $args] == 1} { return [lindex $args 0] }
    if {[llength $args] > 1} {
        return -code error "wrong # args: should be \"get reg key ?default?\""
    }
    return -code error -errorcode {TCLUTILS TUREGISTRY KEY} \
        "registry key not set: \"$key\""
}

proc ::tclutils::turegistry::has {reg key} {
    variable state
    _check $reg
    return [info exists state($reg,k,$key)]
}

# List keys, optionally filtered by a glob pattern.
proc ::tclutils::turegistry::keys {reg {pattern *}} {
    variable state
    _check $reg
    set pre $reg,k,
    set out {}
    foreach k [array names state $pre*] {
        set name [string range $k [string length $pre] end]
        if {[string match $pattern $name]} { lappend out $name }
    }
    return [lsort $out]
}

# Remove a key; returns 1 if it was present, else 0.
proc ::tclutils::turegistry::remove {reg key} {
    variable state
    _check $reg
    if {[info exists state($reg,k,$key)]} {
        unset state($reg,k,$key)
        return 1
    }
    return 0
}

# Destroy a registry and all its entries.
proc ::tclutils::turegistry::destroy {reg} {
    variable state
    _check $reg
    foreach k [array names state $reg,*] { unset state($k) }
    unset state($reg)
    return
}

package provide tclutils::turegistry 0.1
