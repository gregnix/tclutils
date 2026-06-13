# tclutils::tupagespec -- parse and format page-range specifications
#
# Turn a human range string like "1-3,5,7-" into a concrete list of page
# numbers, and the inverse: compact a list of numbers back into "1-3,5,7-9".
# Pure Tcl, no dependencies. 8.6+ / 9.x.
#
#   tupagespec::parse "1-3,5"   10        ;# -> 1 2 3 5
#   tupagespec::parse "5-"      8         ;# -> 5 6 7 8   (open end)
#   tupagespec::parse "-3"      8         ;# -> 1 2 3     (open start)
#   tupagespec::parse "all"     4         ;# -> 1 2 3 4
#   tupagespec::parse "2-4"     10 -base 0 ;# -> 1 2 3    (zero-based output)
#   tupagespec::compact {1 2 3 5 7 8}      ;# -> "1-3,5,7-8"
#
# Error codes: {TCLUTILS TUPAGESPEC SYNTAX|RANGE|OPTION|VALUE}.

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tupagespec {
    namespace export parse compact count
}

# Parse $spec against a page count $total into a sorted, unique list of page
# numbers. Accepts: "" or "all"/"*" (every page); comma-separated parts, each a
# single number N, a range A-B (A>B is tolerated), an open end A- (A..total) or
# open start -B (1..B); the keywords "end"/"last" stand for $total.
# -base 1 (default) returns 1-based page numbers; -base 0 returns 0-based.
proc ::tclutils::tupagespec::parse {spec total args} {
    array set o {-base 1}
    foreach {opt val} $args {
        if {![info exists o($opt)]} {
            return -code error -errorcode {TCLUTILS TUPAGESPEC OPTION} \
                "unknown option '$opt'"
        }
        set o($opt) $val
    }
    if {$o(-base) ni {0 1}} {
        return -code error -errorcode {TCLUTILS TUPAGESPEC VALUE} \
            "-base must be 0 or 1"
    }
    if {![string is integer -strict $total] || $total < 0} {
        return -code error -errorcode {TCLUTILS TUPAGESPEC VALUE} \
            "total must be a non-negative integer"
    }

    set spec [string trim [string tolower $spec]]
    set seen [dict create]

    if {$spec eq "" || $spec eq "all" || $spec eq "*"} {
        for {set i 1} {$i <= $total} {incr i} { dict set seen $i 1 }
    } else {
        foreach part [split $spec ","] {
            set part [string trim $part]
            if {$part eq ""} { continue }
            set part [string map {end %T% last %T%} $part]
            set part [string map [list %T% $total] $part]
            if {[regexp {^(\d+)-(\d+)$} $part -> a b]} {
                if {$a > $b} { lassign [list $b $a] a b }
            } elseif {[regexp {^(\d+)-$} $part -> a]} {
                set b $total
            } elseif {[regexp {^-(\d+)$} $part -> b]} {
                set a 1
            } elseif {[regexp {^(\d+)$} $part -> a]} {
                set b $a
            } else {
                return -code error -errorcode {TCLUTILS TUPAGESPEC SYNTAX} \
                    "invalid page-spec part: '$part'"
            }
            for {set n $a} {$n <= $b} {incr n} {
                if {$n < 1 || $n > $total} {
                    return -code error -errorcode {TCLUTILS TUPAGESPEC RANGE} \
                        "page $n out of range (1..$total)"
                }
                dict set seen $n 1
            }
            # an open-ended start beyond the document selects nothing otherwise
            if {$a > $total} {
                return -code error -errorcode {TCLUTILS TUPAGESPEC RANGE} \
                    "page $a out of range (1..$total)"
            }
        }
    }

    set out {}
    foreach n [lsort -integer [dict keys $seen]] {
        lappend out [expr {$n - (1 - $o(-base))}]
    }
    return $out
}

# Number of pages a spec selects (convenience).
proc ::tclutils::tupagespec::count {spec total} {
    return [llength [parse $spec $total]]
}

# Inverse of parse: group a list of integers into a compact range string,
# e.g. {1 2 3 5 7 8} -> "1-3,5,7-8". Duplicates and order do not matter.
proc ::tclutils::tupagespec::compact {pages} {
    set nums [lsort -integer -unique $pages]
    if {[llength $nums] == 0} { return "" }
    set parts {}
    set start [lindex $nums 0]
    set prev $start
    foreach n [lrange $nums 1 end] {
        if {$n == $prev + 1} {
            set prev $n
            continue
        }
        lappend parts [expr {$start == $prev ? $start : "$start-$prev"}]
        set start $n
        set prev $n
    }
    lappend parts [expr {$start == $prev ? $start : "$start-$prev"}]
    return [join $parts ","]
}

package provide tclutils::tupagespec 0.1
