# tclutils::tugrep -- portable grep-like routines in pure Tcl
# Tcl 8.6+

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tugrep {
    namespace export search file files match
    variable version 0.1.1
}

proc ::tclutils::tugrep::ParseOptions {args} {
    set opts [dict create \
        -nocase 0 \
        -linenumbers 0 \
        -invert 0 \
        -fixed 0 \
        -count 0 \
        -fileswithmatches 0 \
        -filenames 0 \
        -after 0 \
        -before 0 \
        -context 0 \
        -A 0 \
        -B 0 \
        -C 0]
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
    foreach {alias target} {-A -after -B -before -C -context} {
        if {[dict get $opts $alias] ne "0"} {
            dict set opts $target [dict get $opts $alias]
        }
    }
    if {[dict get $opts -context] ne "0"} {
        dict set opts -before [dict get $opts -context]
        dict set opts -after  [dict get $opts -context]
    }
    foreach key {-after -before -context} {
        if {![string is integer -strict [dict get $opts $key]] || [dict get $opts $key] < 0} {
            error "option $key must be a non-negative integer"
        }
    }
    return [list $rest $opts]
}

proc ::tclutils::tugrep::LineMatches {line pattern opts} {
    set nocase [dict get $opts -nocase]
    set fixed [dict get $opts -fixed]
    set invert [dict get $opts -invert]

    if {$fixed} {
        if {$nocase} {
            set ok [expr {[string first [string tolower $pattern] [string tolower $line]] >= 0}]
        } else {
            set ok [expr {[string first $pattern $line] >= 0}]
        }
    } else {
        if {$nocase} {
            set ok [regexp -nocase -- $pattern $line]
        } else {
            set ok [regexp -- $pattern $line]
        }
    }
    if {$invert} { set ok [expr {!$ok}] }
    return $ok
}

proc ::tclutils::tugrep::match {line pattern args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    return [LineMatches $line $pattern $opts]
}

proc ::tclutils::tugrep::FormatMatch {filename n line opts} {
    set item $line
    if {[dict get $opts -linenumbers]} {
        set item [list $n $line]
    }
    if {[dict get $opts -filenames]} {
        set item [list $filename $item]
    }
    return $item
}

proc ::tclutils::tugrep::CollectMatches {lines filename pattern opts} {
    set result {}
    set nlines [llength $lines]
    set before [dict get $opts -before]
    set after  [dict get $opts -after]
    set count 0
    set matched 0
    set include {}

    for {set i 0} {$i < $nlines} {incr i} {
        set line [lindex $lines $i]
        if {[LineMatches $line $pattern $opts]} {
            set matched 1
            incr count
            if {![dict get $opts -count]} {
                set first [expr {$i - $before}]
                if {$first < 0} { set first 0 }
                set last [expr {$i + $after}]
                if {$last >= $nlines} { set last [expr {$nlines - 1}] }
                for {set j $first} {$j <= $last} {incr j} {
                    dict set include $j 1
                }
            }
        }
    }
    if {[dict get $opts -count]} { return [list $count $matched $result] }

    foreach i [lsort -integer [dict keys $include]] {
        lappend result [FormatMatch $filename [expr {$i + 1}] [lindex $lines $i] $opts]
    }
    return [list $count $matched $result]
}

proc ::tclutils::tugrep::search {text pattern args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    lassign [CollectMatches [split $text "\n"] {} $pattern $opts] count matched result
    if {[dict get $opts -count]} { return $count }
    return $result
}

proc ::tclutils::tugrep::file {filename pattern args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }

    set fh [open $filename r]
    try {
        fconfigure $fh -translation auto
        set text [read $fh]
    } finally {
        close $fh
    }
    lassign [CollectMatches [split [string trimright $text "\n"] "\n"] $filename $pattern $opts] count matched result

    if {[dict get $opts -fileswithmatches]} {
        return [expr {$matched ? $filename : ""}]
    }
    if {[dict get $opts -count]} { return $count }
    return $result
}

proc ::tclutils::tugrep::files {fileList pattern args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }

    set result {}
    foreach filename $fileList {
        if {[dict get $opts -fileswithmatches]} {
            set m [file $filename $pattern {*}$args]
            if {$m ne ""} { lappend result $m }
        } else {
            set localArgs $args
            if {![dict get $opts -filenames]} {
                lappend localArgs -filenames 1
            }
            set matches [file $filename $pattern {*}$localArgs]
            if {[dict get $opts -count]} {
                dict set result $filename $matches
            } else {
                foreach match $matches { lappend result $match }
            }
        }
    }
    return $result
}

package provide tclutils::tugrep 0.1
