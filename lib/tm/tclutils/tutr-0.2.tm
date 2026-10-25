# tclutils::tutr -- tr-like character translate/delete helpers
# Description: tr-like character translate/delete helpers
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tutr {
    namespace export translate delete squeeze file
    variable version 0.2
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
            if {$a > $b} {
                return -code error -errorcode {TCLUTILS TUTR RANGE} \
                    "range \"$c-$end\" is descending"
            }
            for {set x $a} {$x <= $b} {incr x} { lappend out [format %c $x] }
            incr i 3
        } else {
            lappend out $c
            incr i
        }
    }
    return $out
}

# Replace the n-th character of set1 by the n-th of set2; a shorter set2 is
# padded with its last character. A character listed twice in set1 maps to
# its last partner, as with tr. An empty set2 is an error.
proc ::tclutils::tutr::translate {text set1 set2} {
    set from [_chars $set1]
    set to [_chars $set2]
    if {[llength $to] == 0} {
        if {[llength $from] == 0} { return $text }
        return -code error -errorcode {TCLUTILS TUTR SET2} \
            "set2 must not be empty"
    }
    set last [lindex $to end]
    set map [dict create]
    for {set i 0} {$i < [llength $from]} {incr i} {
        if {$i < [llength $to]} {
            set r [lindex $to $i]
        } else {
            set r $last
        }
        dict set map [lindex $from $i] $r
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

# File variant. -delete 1 deletes set1 instead of translating; -squeeze 1
# then squeezes the characters of set2. With an empty set2, -squeeze 1 and
# no -delete, set1 is only squeezed (tr -s set1). An empty set2 without
# -delete and -squeeze is an error, as in translate.
proc ::tclutils::tutr::file {path set1 set2 args} {
    set defaults [dict create -delete 0 -squeeze 0]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set del [::tclutils::common::ensureBoolean [dict get $opts -delete] -delete]
    set sq [::tclutils::common::ensureBoolean [dict get $opts -squeeze] -squeeze]
    set text [::tclutils::common::readFile $path]
    if {$del} {
        set text [delete $text $set1]
    } elseif {$sq && $set2 eq ""} {
        return [squeeze $text $set1]
    } else {
        set text [translate $text $set1 $set2]
    }
    if {$sq} {
        set text [squeeze $text $set2]
    }
    return $text
}

package provide tclutils::tutr 0.2
