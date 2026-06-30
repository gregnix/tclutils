# tclutils::tudict -- dict helpers beyond what the Tcl core dict already does.
# Description: dict helpers beyond what the Tcl core dict already does.
# Category: Data · structures & formats
# Pure Tcl, no dependencies.
#
# NOTE: the Tcl core already handles nested access natively -- do NOT wrap these:
#   nested get    : dict get $d a b c
#   nested set    : dict set var a b c $value
#   nested exists : dict exists $d a b c
#   glob filter   : dict filter $d key <pat>   /   dict filter $d value <pat>
# This module adds only what the core lacks: a default-returning nested get,
# leaf-path enumeration, dotted flattening, recursive merge, and inversion.
#
#   tudict::getOr $cfg "" server host        ;# nested get, default if missing
#   tudict::flatten {a {b {c 1}}}            ;# a.b.c -> 1   (dotted keys)
#   tudict::mergeDeep $defaults $overrides   ;# recursive (core merge is shallow)

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tudict {
    namespace export getOr paths flatten mergeDeep invert
    variable version 0.1
}

# Heuristic: treat a value as a (sub)dict if it is a non-empty, even-length list.
# Tcl cannot truly distinguish a dict from a string, so a scalar that happens to
# look like an even-length list (e.g. "a b") may be seen as a dict.
proc ::tclutils::tudict::_isDict {v} {
    return [expr {[llength $v] > 0 && ([llength $v] % 2) == 0 && ![catch {dict size $v}]}]
}

# Nested get returning $default when any key in the path is missing.
proc ::tclutils::tudict::getOr {dict default args} {
    if {![llength $args]} {
        return -code error -errorcode {TCLUTILS TUDICT ARG} "no key path given"
    }
    if {[dict exists $dict {*}$args]} {
        return [dict get $dict {*}$args]
    }
    return $default
}

# List of leaf key-paths (each path is itself a list of keys).
proc ::tclutils::tudict::paths {dict {prefix {}}} {
    set out {}
    dict for {k v} $dict {
        set p [concat $prefix [list $k]]
        if {[_isDict $v]} {
            lappend out {*}[paths $v $p]
        } else {
            lappend out $p
        }
    }
    return $out
}

# Flatten a nested dict to a single level with keys joined by $sep.
proc ::tclutils::tudict::flatten {dict {sep .}} {
    set out [dict create]
    foreach path [paths $dict] {
        dict set out [join $path $sep] [dict get $dict {*}$path]
    }
    return $out
}

# Recursively merge dicts left-to-right; nested dicts merge, scalars overwrite.
proc ::tclutils::tudict::mergeDeep {args} {
    set out [dict create]
    foreach d $args {
        dict for {k v} $d {
            if {[dict exists $out $k] && [_isDict [dict get $out $k]] && [_isDict $v]} {
                dict set out $k [mergeDeep [dict get $out $k] $v]
            } else {
                dict set out $k $v
            }
        }
    }
    return $out
}

# Swap keys and values (last writer wins on duplicate values).
proc ::tclutils::tudict::invert {dict} {
    set out [dict create]
    dict for {k v} $dict { dict set out $v $k }
    return $out
}

package provide tclutils::tudict 0.1
