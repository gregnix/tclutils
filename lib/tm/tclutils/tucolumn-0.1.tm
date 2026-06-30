# tclutils::tucolumn -- column-like columnation in pure Tcl
# Description: column-like columnation in pure Tcl
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucolumn {
    namespace export table fill text file
    variable version 0.1
}

proc ::tclutils::tucolumn::_splitFields {line separator} {
    if {$separator eq ""} {
        # default: split on runs of whitespace, dropping empty leading/trailing
        return [regexp -all -inline {\S+} $line]
    }
    return [::tclutils::common::splitDelimited $line $separator]
}

# Table mode: align delimited columns. Options:
#   -separator S  input field separator (default: whitespace runs)
#   -output S     output column separator (default two spaces)
#   -right 0|1    right-align cells (default 0 = left-align)
proc ::tclutils::tucolumn::table {text args} {
    set defaults [dict create -separator "" -output "  " -right 0]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set sep   [dict get $opts -separator]
    set osep  [dict get $opts -output]
    set right [::tclutils::common::ensureBoolean [dict get $opts -right] -right]

    set rows {}
    set widths {}
    foreach line [::tclutils::common::splitLines $text] {
        set fields [_splitFields $line $sep]
        lappend rows $fields
        set c 0
        foreach f $fields {
            set w [string length $f]
            if {$c >= [llength $widths]} {
                lappend widths $w
            } elseif {$w > [lindex $widths $c]} {
                lset widths $c $w
            }
            incr c
        }
    }

    set out {}
    foreach fields $rows {
        set parts {}
        set last [expr {[llength $fields] - 1}]
        for {set c 0} {$c < [llength $fields]} {incr c} {
            set f [lindex $fields $c]
            set w [lindex $widths $c]
            if {$c == $last} {
                # do not pad the final column (avoid trailing spaces)
                if {$right} {
                    lappend parts [format "%*s" $w $f]
                } else {
                    lappend parts $f
                }
            } elseif {$right} {
                lappend parts [format "%*s" $w $f]
            } else {
                lappend parts [format "%-*s" $w $f]
            }
        }
        lappend out [join $parts $osep]
    }
    return [join $out \n]
}

# Fill mode: arrange items into columns fitting a target width, column-major
# (filling down each column first). Options:
#   -width N   target line width (default 80)
#   -gap N     spaces between columns (default 2)
proc ::tclutils::tucolumn::fill {items args} {
    set defaults [dict create -width 80 -gap 2]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set width [::tclutils::common::ensurePositiveInteger [dict get $opts -width] -width]
    set gap   [::tclutils::common::ensurePositiveInteger [dict get $opts -gap] -gap]

    set n [llength $items]
    if {$n == 0} { return "" }
    set maxw 0
    foreach it $items {
        set w [string length $it]
        if {$w > $maxw} { set maxw $w }
    }
    set colw [expr {$maxw + $gap}]
    set cols [expr {($width + $gap) / $colw}]
    if {$cols < 1} { set cols 1 }
    set rows [expr {($n + $cols - 1) / $cols}]

    set out {}
    for {set r 0} {$r < $rows} {incr r} {
        set parts {}
        for {set c 0} {$c < $cols} {incr c} {
            set idx [expr {$r + $c * $rows}]
            if {$idx >= $n} { continue }
            set it [lindex $items $idx]
            # pad all but the visually last cell in the row
            set nextIdx [expr {$r + ($c + 1) * $rows}]
            if {$nextIdx < $n} {
                lappend parts [format "%-*s" $maxw $it][string repeat " " $gap]
            } else {
                lappend parts $it
            }
        }
        lappend out [string trimright [join $parts ""]]
    }
    return [join $out \n]
}

# `text` is an alias for table mode (the common case).
proc ::tclutils::tucolumn::text {text args} {
    return [table $text {*}$args]
}

# File variant. Option -mode table|fill (default table) plus mode options.
proc ::tclutils::tucolumn::file {path args} {
    set mode table
    set rest {}
    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        if {$a eq "-mode"} {
            incr i
            if {$i >= [llength $args]} {
                return -code error -errorcode {TCLUTILS TUCOLUMN OPTION} "missing value for option \"-mode\""
            }
            set mode [lindex $args $i]
        } else {
            lappend rest $a
        }
        incr i
    }
    set data [::tclutils::common::readFile $path]
    switch -- $mode {
        table { return [table $data {*}$rest] }
        fill  { return [fill [regexp -all -inline {\S+} $data] {*}$rest] }
        default {
            return -code error -errorcode {TCLUTILS TUCOLUMN MODE} \
                "invalid -mode \"$mode\": must be table or fill"
        }
    }
}

package provide tclutils::tucolumn 0.1
