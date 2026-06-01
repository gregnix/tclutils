# tclutils::tufuzzy -- fuzzy matching primitives in pure Tcl
# Tcl 8.6+

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tufuzzy {
    namespace export distance searchDistance similarity subsequence bestMatch
    variable version 0.1
}

proc ::tclutils::tufuzzy::Chars {s} {
    if {$s eq ""} { return {} }
    return [split $s ""]
}

proc ::tclutils::tufuzzy::ParseOptions {args} {
    set opts [dict create -nocase 0]
    set rest {}
    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        if {[string match -* $a]} {
            if {![dict exists $opts $a]} { error "unknown option $a" }
            incr i
            if {$i >= [llength $args]} { error "missing value for option $a" }
            dict set opts $a [lindex $args $i]
        } else {
            lappend rest $a
        }
        incr i
    }
    return [list $rest $opts]
}

proc ::tclutils::tufuzzy::NormalizePair {a b opts} {
    if {[dict get $opts -nocase]} {
        set a [string tolower $a]
        set b [string tolower $b]
    }
    return [list $a $b]
}

proc ::tclutils::tufuzzy::distance {a b args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    lassign [NormalizePair $a $b $opts] a b

    set ac [Chars $a]
    set bc [Chars $b]
    set m [llength $ac]
    set n [llength $bc]
    if {$m == 0} { return $n }
    if {$n == 0} { return $m }

    set prev {}
    for {set j 0} {$j <= $n} {incr j} { lappend prev $j }

    for {set i 1} {$i <= $m} {incr i} {
        set ca [lindex $ac [expr {$i - 1}]]
        set curr [list $i]
        for {set j 1} {$j <= $n} {incr j} {
            set cb [lindex $bc [expr {$j - 1}]]
            set cost [expr {$ca eq $cb ? 0 : 1}]
            set del [expr {[lindex $prev $j] + 1}]
            set ins [expr {[lindex $curr [expr {$j - 1}]] + 1}]
            set sub [expr {[lindex $prev [expr {$j - 1}]] + $cost}]
            set best [expr {$del < $ins ? $del : $ins}]
            if {$sub < $best} { set best $sub }
            lappend curr $best
        }
        set prev $curr
    }
    return [lindex $prev end]
}

proc ::tclutils::tufuzzy::searchDistance {pattern text args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    lassign [NormalizePair $pattern $text $opts] pattern text

    set pc [Chars $pattern]
    set tc [Chars $text]
    set m [llength $pc]
    set n [llength $tc]
    if {$m == 0} { return 0 }
    if {$n == 0} { return $m }

    # Approximate substring distance: matching may start/end anywhere in text.
    # Initialize row 0 to all zero so leading text chars are free.
    set prev {}
    for {set j 0} {$j <= $n} {incr j} { lappend prev 0 }

    for {set i 1} {$i <= $m} {incr i} {
        set cp [lindex $pc [expr {$i - 1}]]
        set curr [list $i]
        for {set j 1} {$j <= $n} {incr j} {
            set ct [lindex $tc [expr {$j - 1}]]
            set cost [expr {$cp eq $ct ? 0 : 1}]
            set del [expr {[lindex $prev $j] + 1}]
            set ins [expr {[lindex $curr [expr {$j - 1}]] + 1}]
            set sub [expr {[lindex $prev [expr {$j - 1}]] + $cost}]
            set best [expr {$del < $ins ? $del : $ins}]
            if {$sub < $best} { set best $sub }
            lappend curr $best
        }
        set prev $curr
    }

    set best [lindex $prev 0]
    foreach v $prev { if {$v < $best} { set best $v } }
    return $best
}

proc ::tclutils::tufuzzy::similarity {a b args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    lassign [NormalizePair $a $b $opts] a b
    set maxLen [expr {[string length $a] > [string length $b] ? [string length $a] : [string length $b]}]
    if {$maxLen == 0} { return 1.0 }
    set d [distance $a $b]
    set score [expr {1.0 - (double($d) / double($maxLen))}]
    if {$score < 0.0} { return 0.0 }
    return $score
}

proc ::tclutils::tufuzzy::subsequence {pattern text args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    lassign [NormalizePair $pattern $text $opts] pattern text
    set pc [Chars $pattern]
    if {[llength $pc] == 0} { return 1 }
    set idx 0
    foreach ch [Chars $text] {
        if {$ch eq [lindex $pc $idx]} {
            incr idx
            if {$idx >= [llength $pc]} { return 1 }
        }
    }
    return 0
}

proc ::tclutils::tufuzzy::bestMatch {pattern candidates args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    if {[llength $candidates] == 0} { return "" }
    set best ""
    set bestDist ""
    foreach candidate $candidates {
        set d [distance $pattern $candidate {*}$args]
        if {$bestDist eq "" || $d < $bestDist} {
            set bestDist $d
            set best $candidate
        }
    }
    return $best
}

package provide tclutils::tufuzzy 0.1
