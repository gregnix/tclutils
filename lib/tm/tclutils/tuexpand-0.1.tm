# tclutils::tuexpand -- expand/unexpand (tabs <-> spaces) in pure Tcl
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuexpand {
    namespace export expand unexpand file
    variable version 0.1
}

proc ::tclutils::tuexpand::_tabsize {args} {
    set defaults [dict create -tabs 8 -all 0]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set ts [::tclutils::common::ensurePositiveInteger [dict get $opts -tabs] -tabs]
    set all [::tclutils::common::ensureBoolean [dict get $opts -all] -all]
    return [list $ts $all]
}

# Expand tabs in one line to spaces, aligning to the next tab stop.
proc ::tclutils::tuexpand::_expandLine {line tabsize} {
    set out ""
    set col 0
    foreach c [split $line ""] {
        if {$c eq "\t"} {
            set n [expr {$tabsize - ($col % $tabsize)}]
            append out [string repeat " " $n]
            incr col $n
        } else {
            append out $c
            incr col
        }
    }
    return $out
}

proc ::tclutils::tuexpand::_nextStop {col tabsize} {
    return [expr {(($col / $tabsize) + 1) * $tabsize}]
}

# Convert a run of `nspaces` spaces starting at column `startCol` into tabs and
# trailing spaces. A tab is emitted only when it spans at least two columns to
# the next tab stop, so single spaces are never turned into tabs.
proc ::tclutils::tuexpand::_convertRun {startCol nspaces tabsize} {
    set out ""
    set col $startCol
    set remaining $nspaces
    while {$remaining > 0} {
        set stop [_nextStop $col $tabsize]
        set dist [expr {$stop - $col}]
        if {$dist >= 2 && $remaining >= $dist} {
            append out "\t"
            set remaining [expr {$remaining - $dist}]
            set col $stop
        } else {
            append out [string repeat " " $remaining]
            incr col $remaining
            set remaining 0
        }
    }
    return $out
}

proc ::tclutils::tuexpand::_unexpandLine {line tabsize all} {
    set s [_expandLine $line $tabsize]
    if {!$all} {
        regexp {^( *)(.*)$} $s -> lead rest
        return "[_convertRun 0 [string length $lead] $tabsize]$rest"
    }
    set out ""
    set col 0
    set i 0
    set n [string length $s]
    while {$i < $n} {
        if {[string index $s $i] eq " "} {
            set j $i
            while {$j < $n && [string index $s $j] eq " "} { incr j }
            set nsp [expr {$j - $i}]
            append out [_convertRun $col $nsp $tabsize]
            incr col $nsp
            set i $j
        } else {
            append out [string index $s $i]
            incr col
            incr i
        }
    }
    return $out
}

proc ::tclutils::tuexpand::_eachLine {text tabsize procName all} {
    set trailing 0
    set lines [split $text \n]
    if {$text ne "" && [string index $text end] eq "\n"} {
        set lines [lrange $lines 0 end-1]
        set trailing 1
    }
    set out {}
    foreach l $lines {
        if {$procName eq "expand"} {
            lappend out [_expandLine $l $tabsize]
        } else {
            lappend out [_unexpandLine $l $tabsize $all]
        }
    }
    set result [join $out \n]
    if {$trailing} { append result \n }
    return $result
}

# Convert tabs to spaces. Option: -tabs N (tab width, default 8).
proc ::tclutils::tuexpand::expand {text args} {
    lassign [_tabsize {*}$args] ts all
    return [_eachLine $text $ts expand $all]
}

# Convert spaces to tabs. Options: -tabs N (default 8), -all 0|1 (default 0 =
# only leading blanks, like unexpand; 1 converts all blank runs).
proc ::tclutils::tuexpand::unexpand {text args} {
    lassign [_tabsize {*}$args] ts all
    return [_eachLine $text $ts unexpand $all]
}

# File variant. Option -mode expand|unexpand (default expand) plus -tabs/-all.
proc ::tclutils::tuexpand::file {path args} {
    set mode expand
    set rest {}
    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        if {$a eq "-mode"} {
            incr i
            if {$i >= [llength $args]} {
                return -code error -errorcode {TCLUTILS TUEXPAND OPTION} "missing value for option \"-mode\""
            }
            set mode [lindex $args $i]
        } else {
            lappend rest $a
        }
        incr i
    }
    set data [::tclutils::common::readFile $path]
    switch -- $mode {
        expand   { return [expand $data {*}$rest] }
        unexpand { return [unexpand $data {*}$rest] }
        default {
            return -code error -errorcode {TCLUTILS TUEXPAND MODE} \
                "invalid -mode \"$mode\": must be expand or unexpand"
        }
    }
}

package provide tclutils::tuexpand 0.1
