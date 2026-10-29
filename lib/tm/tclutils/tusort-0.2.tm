# tclutils::tusort -- sort-like helpers
# Description: sort-like helpers
# Category: Text · strings/coreutils
#
# Line ends: text/file output ends with LF exactly when the input does
# ("Jörg\n" stays "Jörg\n", "Jörg" stays "Jörg"), like tuhead, tutail, tunl,
# tutac and tused. Versions before 0.2 dropped the final LF.
package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tusort { namespace export sortList text file }

proc ::tclutils::tusort::_parseOptions {args} {
    set opts [dict create -ascii 0 -dictionary 0 -integer 0 -real 0 -numeric 0 -nocase 0 -reverse 0 -unique 0 -decreasing 0 -increasing 1]
    set i 0
    while {$i < [llength $args]} {
        set opt [lindex $args $i]
        if {![dict exists $opts $opt]} {
            return -code error "unknown option \"$opt\""
        }
        incr i
        if {$i >= [llength $args]} {
            return -code error "missing value for option \"$opt\""
        }
        set val [lindex $args $i]
        if {![string is boolean -strict $val]} {
            return -code error "option \"$opt\" requires a boolean value"
        }
        dict set opts $opt [expr {$val ? 1 : 0}]
        incr i
    }
    return $opts
}

proc ::tclutils::tusort::_lsortOptions {opts} {
    set out {}
    foreach {flag lsortFlag} {
        -ascii -ascii
        -dictionary -dictionary
        -integer -integer
        -real -real
    } {
        if {[dict get $opts $flag]} { lappend out $lsortFlag }
    }
    if {[dict get $opts -numeric]} { lappend out -real }
    if {[dict get $opts -nocase]} { lappend out -nocase }
    if {[dict get $opts -reverse] || [dict get $opts -decreasing]} {
        lappend out -decreasing
    } elseif {[dict get $opts -increasing]} {
        lappend out -increasing
    }
    if {[dict get $opts -unique]} { lappend out -unique }
    return $out
}

proc ::tclutils::tusort::sortList {items args} {
    set opts [_parseOptions {*}$args]
    set sortOpts [_lsortOptions $opts]
    return [lsort {*}$sortOpts $items]
}

# Join $lines with LF; one LF more at the end when $text ends with LF.
proc ::tclutils::tusort::_joinLines {lines text} {
    set out [join $lines \n]
    if {[llength $lines] && [string index $text end] eq "\n"} { append out \n }
    return $out
}

proc ::tclutils::tusort::text {text args} {
    set lines [split $text \n]
    # Ignore one trailing empty list element caused by a final newline.  This
    # mirrors file line processing and avoids sorting an artificial empty line.
    if {[llength $lines] > 0 && [lindex $lines end] eq ""} {
        set lines [lrange $lines 0 end-1]
    }
    return [_joinLines \
        [::tclutils::tusort::sortList $lines {*}$args] $text]
}

proc ::tclutils::tusort::file {path args} {
    set data [::tclutils::common::readFile $path]
    return [text $data {*}$args]
}

package provide tclutils::tusort 0.2
