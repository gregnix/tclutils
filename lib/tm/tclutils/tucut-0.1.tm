# tclutils::tucut -- cut-like helpers for simple delimited text and characters
# Description: cut-like helpers for simple delimited text and characters
# Category: Text · strings/coreutils
package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucut { namespace export field fields chars line text file }

proc ::tclutils::tucut::_parseOptions {args} {
    set opts [dict create -delimiter "\t" -fields {} -chars {} -joiner {}]
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
        dict set opts $opt [lindex $args $i]
        incr i
    }
    if {[dict get $opts -joiner] eq {}} {
        dict set opts -joiner [dict get $opts -delimiter]
    }
    if {[llength [dict get $opts -fields]] > 0 && [llength [dict get $opts -chars]] > 0} {
        return -code error "options -fields and -chars are mutually exclusive"
    }
    return $opts
}

proc ::tclutils::tucut::_normalizeRanges {rangeSpec label} {
    set out {}
    foreach spec $rangeSpec {
        if {[regexp {^([0-9]+)-([0-9]+)$} $spec -> a b]} {
            if {$a < 1 || $b < $a} { return -code error "invalid $label range \"$spec\"" }
            for {set i $a} {$i <= $b} {incr i} { lappend out $i }
        } elseif {[regexp {^([0-9]+)-$} $spec -> a]} {
            if {$a < 1} { return -code error "invalid $label range \"$spec\"" }
            lappend out [list from $a]
        } elseif {[regexp {^-([0-9]+)$} $spec -> b]} {
            if {$b < 1} { return -code error "invalid $label range \"$spec\"" }
            lappend out [list to $b]
        } elseif {[string is integer -strict $spec] && $spec >= 1} {
            lappend out $spec
        } else {
            return -code error "invalid $label \"$spec\""
        }
    }
    return $out
}

proc ::tclutils::tucut::_normalizeFields {fieldSpec} {
    set normalized [_normalizeRanges $fieldSpec field]
    set out {}
    foreach spec $normalized {
        if {[llength $spec] > 1} {
            return -code error "open-ended field ranges are not supported"
        }
        lappend out $spec
    }
    return $out
}

proc ::tclutils::tucut::_charIndexes {charSpec length} {
    set out {}
    foreach spec [_normalizeRanges $charSpec character] {
        if {[llength $spec] > 1} {
            lassign $spec kind n
            if {$kind eq "from"} {
                for {set i $n} {$i <= $length} {incr i} { lappend out $i }
            } else {
                for {set i 1} {$i <= $n && $i <= $length} {incr i} { lappend out $i }
            }
        } elseif {$spec <= $length} {
            lappend out $spec
        }
    }
    return $out
}

proc ::tclutils::tucut::field {line delimiter index} {
    if {![string is integer -strict $index] || $index < 1} {
        return -code error "field index must be a positive integer"
    }
    return [lindex [::tclutils::common::splitDelimited $line $delimiter] [expr {$index - 1}]]
}

proc ::tclutils::tucut::fields {line delimiter fieldSpec {joiner {}}} {
    if {$joiner eq {}} { set joiner $delimiter }
    set parts [::tclutils::common::splitDelimited $line $delimiter]
    set out {}
    foreach idx [_normalizeFields $fieldSpec] {
        lappend out [lindex $parts [expr {$idx - 1}]]
    }
    return [join $out $joiner]
}

proc ::tclutils::tucut::chars {line charSpec} {
    set out {}
    set len [string length $line]
    foreach idx [_charIndexes $charSpec $len] {
        lappend out [string index $line [expr {$idx - 1}]]
    }
    return [join $out ""]
}

proc ::tclutils::tucut::line {line args} {
    set opts [_parseOptions {*}$args]
    set charSpec [dict get $opts -chars]
    if {[llength $charSpec] > 0} {
        return [chars $line $charSpec]
    }
    set fieldSpec [dict get $opts -fields]
    if {[llength $fieldSpec] == 0} { return $line }
    return [fields $line [dict get $opts -delimiter] $fieldSpec [dict get $opts -joiner]]
}

proc ::tclutils::tucut::text {text args} {
    set lines [split $text \n]
    if {[llength $lines] > 0 && [lindex $lines end] eq ""} {
        set lines [lrange $lines 0 end-1]
    }
    set out {}
    foreach l $lines { lappend out [line $l {*}$args] }
    return [join $out \n]
}

proc ::tclutils::tucut::file {path args} {
    return [text [::tclutils::common::readFile $path] {*}$args]
}

package provide tclutils::tucut 0.1
