# tclutils::tusize -- directory/file sizes (a small `du`)
# Description: directory/file sizes (a small `du`)
# Category: Archive · filesystem
# Tcl 8.6+
#
# Recursive byte totals plus human-readable formatting. Symlinks are NOT
# followed (their own entry size is counted), so cyclic links cannot loop.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tusize {
    namespace export bytes human entries
    variable version 0.1
}

# All immediate children of a directory, including dotfiles, excluding . and ..
proc ::tclutils::tusize::_children {dir} {
    set kids {}
    foreach pat {* .*} {
        foreach c [glob -nocomplain -directory $dir -- $pat] {
            set tail [file tail $c]
            if {$tail eq "." || $tail eq ".."} { continue }
            lappend kids $c
        }
    }
    return [lsort -unique $kids]
}

# Total size in bytes of a file, or the recursive total of a directory.
proc ::tclutils::tusize::bytes {path} {
    if {[catch {file type $path} type]} {
        return -code error -errorcode {TCLUTILS TUSIZE NOTFOUND} "no such path: $path"
    }
    switch -- $type {
        link {
            if {[catch {file size $path} s]} { return 0 }
            return $s
        }
        directory {
            set total 0
            foreach c [_children $path] { incr total [bytes $c] }
            return $total
        }
        default {
            if {[catch {file size $path} s]} { return 0 }
            return $s
        }
    }
}

# Human-readable size. Default uses binary units (1024 -> KiB/MiB/...).
# With -si 1, decimal units are used (1000 -> kB/MB/...).
proc ::tclutils::tusize::human {n args} {
    set opts [::tclutils::common::parseOptions [dict create -si 0] {*}$args]
    set si [::tclutils::common::ensureBoolean [dict get $opts -si] -si]
    if {![string is entier -strict $n]} {
        return -code error -errorcode {TCLUTILS TUSIZE VALUE} "byte count must be an integer"
    }
    set base [expr {$si ? 1000 : 1024}]
    set units [expr {$si ? {B kB MB GB TB PB} : {B KiB MiB GiB TiB PiB}}]
    set size [expr {double($n)}]
    set i 0
    set last [expr {[llength $units] - 1}]
    while {abs($size) >= $base && $i < $last} {
        set size [expr {$size / $base}]
        incr i
    }
    if {$i == 0} { return "$n [lindex $units 0]" }
    return [format "%.1f %s" $size [lindex $units $i]]
}

# du-style listing: {bytes path} for every immediate child of a directory,
# sorted by path. Directory children carry their recursive total.
proc ::tclutils::tusize::entries {dir} {
    if {[catch {file type $dir} t] || $t ne "directory"} {
        return -code error -errorcode {TCLUTILS TUSIZE NOTDIR} "not a directory: $dir"
    }
    set out {}
    foreach c [_children $dir] {
        lappend out [list [bytes $c] $c]
    }
    return [lsort -index 1 $out]
}

package provide tclutils::tusize 0.1
