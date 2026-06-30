# tclutils::tutr -- tr-like character translate/delete helpers
# Description: tr-like character translate/delete helpers
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tutr {
    namespace export translate delete squeeze file
    variable version 0.1
}

proc ::tclutils::tutr::_chars {spec} {
    set out {}
    set n [string length $spec]
    set i 0
    while {$i < $n} {
        set c [string index $spec $i]
        if {$i + 2 < $n && [string index $spec [expr {$i + 1}]] eq "-"} {
            set end [string index $spec [expr {$i + 2}]]
            scan $c %c a
            scan $end %c b
            if {$a <= $b} {
                for {set x $a} {$x <= $b} {incr x} { lappend out [format %c $x] }
            } else {
                for {set x $a} {$x >= $b} {incr x -1} { lappend out [format %c $x] }
            }
            incr i 3
        } else {
            lappend out $c
            incr i
        }
    }
    return $out
}

proc ::tclutils::tutr::translate {text set1 set2} {
    set from [_chars $set1]
    set to [_chars $set2]
    if {[llength $to] == 0} { return $text }
    set last [lindex $to end]
    set map {}
    for {set i 0} {$i < [llength $from]} {incr i} {
        if {$i < [llength $to]} {
            set r [lindex $to $i]
        } else {
            set r $last
        }
        lappend map [lindex $from $i] $r
    }
    return [string map $map $text]
}

proc ::tclutils::tutr::delete {text set1} {
    set map {}
    foreach c [_chars $set1] { lappend map $c "" }
    return [string map $map $text]
}

proc ::tclutils::tutr::squeeze {text set1} {
    set chars [_chars $set1]
    set table [dict create]
    foreach c $chars { dict set table $c 1 }
    set out ""
    set prev ""
    foreach c [split $text ""] {
        if {$c eq $prev && [dict exists $table $c]} {
            continue
        }
        append out $c
        set prev $c
    }
    return $out
}

proc ::tclutils::tutr::file {path set1 set2 args} {
    set defaults [dict create -delete 0 -squeeze 0]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set text [::tclutils::common::readFile $path]
    if {[::tclutils::common::ensureBoolean [dict get $opts -delete] -delete]} {
        set text [delete $text $set1]
    } else {
        set text [translate $text $set1 $set2]
    }
    if {[::tclutils::common::ensureBoolean [dict get $opts -squeeze] -squeeze]} {
        set text [squeeze $text $set2]
    }
    return $text
}

package provide tclutils::tutr 0.1
