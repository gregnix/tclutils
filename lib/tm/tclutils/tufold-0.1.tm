# tclutils::tufold -- fold-like text wrapping helpers
# Description: fold-like text wrapping helpers
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tufold {
    namespace export foldLine text file
    variable version 0.1
}

proc ::tclutils::tufold::_options {args} {
    set defaults [dict create -width 80 -words 0]
    return [::tclutils::common::parseOptions $defaults {*}$args]
}

proc ::tclutils::tufold::_foldHard {line width} {
    set out {}
    set n [string length $line]
    for {set i 0} {$i < $n} {incr i $width} {
        lappend out [string range $line $i [expr {$i + $width - 1}]]
    }
    if {$n == 0} { return [list ""] }
    return $out
}

proc ::tclutils::tufold::_foldWords {line width} {
    if {[string length $line] <= $width} { return [list $line] }
    set out {}
    set rest $line
    while {[string length $rest] > $width} {
        set cut [string last " " [string range $rest 0 $width]]
        if {$cut <= 0} {
            set cut $width
            lappend out [string range $rest 0 [expr {$cut - 1}]]
            set rest [string range $rest $cut end]
        } else {
            lappend out [string range $rest 0 [expr {$cut - 1}]]
            set rest [string trimleft [string range $rest [expr {$cut + 1}] end]]
        }
    }
    lappend out $rest
    return $out
}

proc ::tclutils::tufold::foldLine {line args} {
    set opts [_options {*}$args]
    set width [::tclutils::common::ensurePositiveInteger [dict get $opts -width] -width]
    set words [::tclutils::common::ensureBoolean [dict get $opts -words] -words]
    if {$words} {
        return [_foldWords $line $width]
    }
    return [_foldHard $line $width]
}

proc ::tclutils::tufold::text {input args} {
    set opts [_options {*}$args]
    set out {}
    foreach line [::tclutils::common::splitLines $input] {
        foreach folded [foldLine $line {*}$opts] {
            lappend out $folded
        }
    }
    return [join $out \n]
}

proc ::tclutils::tufold::file {path args} {
    set data [::tclutils::common::readFile $path]
    return [text $data {*}$args]
}

package provide tclutils::tufold 0.1
