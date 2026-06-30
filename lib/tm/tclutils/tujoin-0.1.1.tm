# tclutils::tujoin -- simple join-like helpers for delimited text
# Description: simple join-like helpers for delimited text
# Category: Text · strings/coreutils
package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tujoin { namespace export lines texts files }

proc ::tclutils::tujoin::_parseOptions {args} {
    set opts [dict create -delimiter "\t" -leftfield 1 -rightfield 1 -joiner {} -header 0 -outer none -anti none]
    set i 0
    while {$i < [llength $args]} {
        set opt [lindex $args $i]
        if {![dict exists $opts $opt]} { return -code error "unknown option \"$opt\"" }
        incr i
        if {$i >= [llength $args]} { return -code error "missing value for option \"$opt\"" }
        dict set opts $opt [lindex $args $i]
        incr i
    }
    foreach opt {-leftfield -rightfield} {
        set v [dict get $opts $opt]
        if {![string is integer -strict $v] || $v < 1} {
            return -code error "$opt requires a positive integer"
        }
    }
    if {![string is boolean -strict [dict get $opts -header]]} {
        return -code error "-header requires a boolean value"
    }
    set outer [dict get $opts -outer]
    if {$outer ni {none left right full}} {
        return -code error "-outer must be one of: none, left, right, full"
    }
    set anti [dict get $opts -anti]
    if {$anti ni {none left right both}} {
        return -code error "-anti must be one of: none, left, right, both"
    }
    if {$outer ne "none" && $anti ne "none"} {
        return -code error "cannot combine -outer and -anti"
    }
    if {[dict get $opts -joiner] eq {}} { dict set opts -joiner [dict get $opts -delimiter] }
    return $opts
}

proc ::tclutils::tujoin::_withoutIndex {items index0} {
    set out {}
    for {set i 0} {$i < [llength $items]} {incr i} {
        if {$i != $index0} { lappend out [lindex $items $i] }
    }
    return $out
}

proc ::tclutils::tujoin::_blankList {count} {
    set out {}
    for {set i 0} {$i < $count} {incr i} { lappend out "" }
    return $out
}

proc ::tclutils::tujoin::_maxColumns {lines delimiter start} {
    set max 0
    for {set i $start} {$i < [llength $lines]} {incr i} {
        set n [llength [::tclutils::common::splitDelimited [lindex $lines $i] $delimiter]]
        if {$n > $max} { set max $n }
    }
    return $max
}

proc ::tclutils::tujoin::_compose {key lp lf rp rf joiner} {
    return [join [concat [list $key] [_withoutIndex $lp $lf] [_withoutIndex $rp $rf]] $joiner]
}

proc ::tclutils::tujoin::_textLines {text} {
    set lines [split $text \n]
    if {[llength $lines] > 0 && [lindex $lines end] eq ""} { set lines [lrange $lines 0 end-1] }
    return $lines
}

proc ::tclutils::tujoin::lines {leftLines rightLines args} {
    set opts [_parseOptions {*}$args]
    set delimiter [dict get $opts -delimiter]
    set joiner [dict get $opts -joiner]
    set lf [expr {[dict get $opts -leftfield] - 1}]
    set rf [expr {[dict get $opts -rightfield] - 1}]
    set header [expr {[dict get $opts -header] ? 1 : 0}]
    set outer [dict get $opts -outer]

    set startR $header
    set rightIndex [dict create]
    set matchedRight [dict create]
    set rightRows {}
    for {set i $startR} {$i < [llength $rightLines]} {incr i} {
        set parts [::tclutils::common::splitDelimited [lindex $rightLines $i] $delimiter]
        set key [lindex $parts $rf]
        lappend rightRows [list $i $key $parts]
        dict lappend rightIndex $key [list $i $parts]
    }

    set anti [dict get $opts -anti]
    if {$anti ne "none"} {
        set matchedRight [dict create]
        set emitLeft [expr {$anti in {left both}}]
        set emitRight [expr {$anti in {right both}}]
        set out {}
        for {set i $header} {$i < [llength $leftLines]} {incr i} {
            set lp [::tclutils::common::splitDelimited [lindex $leftLines $i] $delimiter]
            set key [lindex $lp $lf]
            if {[dict exists $rightIndex $key]} {
                foreach pair [dict get $rightIndex $key] {
                    lassign $pair ri rp
                    dict set matchedRight $ri 1
                }
            } elseif {$emitLeft} {
                lappend out [_compose $key $lp $lf {} $rf $joiner]
            }
        }
        if {$emitRight} {
            foreach row $rightRows {
                lassign $row ri key rp
                if {[dict exists $matchedRight $ri]} { continue }
                lappend out [_compose $key {} $lf $rp $rf $joiner]
            }
        }
        return [join $out \n]
    }

    set leftCols [_maxColumns $leftLines $delimiter $header]
    set rightCols [_maxColumns $rightLines $delimiter $header]
    if {$header && [llength $leftLines] > 0} {
        set leftCols [expr {max($leftCols, [llength [::tclutils::common::splitDelimited [lindex $leftLines 0] $delimiter]])}]
    }
    if {$header && [llength $rightLines] > 0} {
        set rightCols [expr {max($rightCols, [llength [::tclutils::common::splitDelimited [lindex $rightLines 0] $delimiter]])}]
    }
    set blankLeft [_blankList $leftCols]
    set blankRight [_blankList $rightCols]

    set out {}
    if {$header && [llength $leftLines] > 0 && [llength $rightLines] > 0} {
        set lp [::tclutils::common::splitDelimited [lindex $leftLines 0] $delimiter]
        set rp [::tclutils::common::splitDelimited [lindex $rightLines 0] $delimiter]
        lappend out [_compose [lindex $lp $lf] $lp $lf $rp $rf $joiner]
    }

    for {set i $header} {$i < [llength $leftLines]} {incr i} {
        set lp [::tclutils::common::splitDelimited [lindex $leftLines $i] $delimiter]
        set key [lindex $lp $lf]
        if {[dict exists $rightIndex $key]} {
            foreach pair [dict get $rightIndex $key] {
                lassign $pair ri rp
                dict set matchedRight $ri 1
                lappend out [_compose $key $lp $lf $rp $rf $joiner]
            }
        } elseif {$outer in {left full}} {
            lappend out [_compose $key $lp $lf $blankRight $rf $joiner]
        }
    }

    if {$outer in {right full}} {
        foreach row $rightRows {
            lassign $row ri key rp
            if {[dict exists $matchedRight $ri]} { continue }
            lappend out [_compose $key $blankLeft $lf $rp $rf $joiner]
        }
    }
    return [join $out \n]
}

proc ::tclutils::tujoin::texts {leftText rightText args} {
    return [lines [_textLines $leftText] [_textLines $rightText] {*}$args]
}

proc ::tclutils::tujoin::files {leftPath rightPath args} {
    set left [::tclutils::common::readFile $leftPath]
    set right [::tclutils::common::readFile $rightPath]
    return [texts $left $right {*}$args]
}

package provide tclutils::tujoin 0.1.1
