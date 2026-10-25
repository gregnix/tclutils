# tclutils::tuexpand -- expand/unexpand (tabs <-> spaces) in pure Tcl
# Description: expand/unexpand (tabs <-> spaces) in pure Tcl
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuexpand {
    namespace export expand unexpand file
    variable version 0.2
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

# Convert spaces to tabs in one line. Without ALL only the leading run of
# blanks (spaces and tabs) is converted and the rest of the line is copied
# unchanged. With ALL every run of blanks is converted. Within a run of two
# or more blanks (or a run at the start of the line) each tab stop the run
# reaches becomes a tab; a single space inside the line stays a space, a tab
# stays a tab. Spaces just before a tab are absorbed by it.
proc ::tclutils::tuexpand::_unexpandLine {line tabsize all} {
    set out ""
    set col 0
    set i 0
    set n [string length $line]
    set leading 1
    while {$i < $n} {
        set c [string index $line $i]
        if {($c eq " " || $c eq "\t") && ($all || $leading)} {
            set j $i
            while {$j < $n && [string index $line $j] in {" " "\t"}} {
                incr j
            }
            set run [expr {$j - $i}]
            set pend 0
            for {set k $i} {$k < $j} {incr k} {
                if {[string index $line $k] eq "\t"} {
                    append out "\t"
                    set col [_nextStop $col $tabsize]
                    set pend 0
                    continue
                }
                incr col
                incr pend
                if {($run >= 2 || $i == 0) && $col % $tabsize == 0} {
                    append out "\t"
                    set pend 0
                }
            }
            append out [string repeat " " $pend]
            set i $j
            set leading 0
            continue
        }
        if {$c eq "\t"} {
            set col [_nextStop $col $tabsize]
        } else {
            incr col
        }
        append out $c
        set leading 0
        incr i
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

# Convert tabs to spaces. Option: -tabs N (tab width, default 8). -all
# belongs to unexpand only and is rejected here as an unknown option.
proc ::tclutils::tuexpand::expand {text args} {
    set opts [::tclutils::common::parseOptions {-tabs 8} {*}$args]
    set ts [::tclutils::common::ensurePositiveInteger [dict get $opts -tabs] -tabs]
    return [_eachLine $text $ts expand 0]
}

# Convert spaces to tabs. Options: -tabs N (default 8), -all 0|1 (default 0 =
# only the leading blanks, like unexpand; 1 converts all blank runs, like
# unexpand -a). Tabs inside the line stay as they are.
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

package provide tclutils::tuexpand 0.2
