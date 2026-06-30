# tclutils::tuagrep -- approximate grep-like routines in pure Tcl
# Description: approximate grep-like routines in pure Tcl
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::tufuzzy 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuagrep {
    namespace export search file files match
    variable version 0.1
}

proc ::tclutils::tuagrep::ParseOptions {args} {
    set opts [dict create \
        -maxdist 1 \
        -nocase 0 \
        -linenumbers 0 \
        -invert 0 \
        -count 0 \
        -fileswithmatches 0 \
        -filenames 0]
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

proc ::tclutils::tuagrep::LineMatches {line pattern opts} {
    set d [::tclutils::tufuzzy::searchDistance \
        $pattern $line \
        -nocase [dict get $opts -nocase]]
    set ok [expr {$d <= [dict get $opts -maxdist]}]
    if {[dict get $opts -invert]} { set ok [expr {!$ok}] }
    return $ok
}

proc ::tclutils::tuagrep::match {line pattern args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    return [LineMatches $line $pattern $opts]
}

proc ::tclutils::tuagrep::FormatMatch {filename n line opts} {
    set item $line
    if {[dict get $opts -linenumbers]} {
        set item [list $n $line]
    }
    if {[dict get $opts -filenames]} {
        set item [list $filename $item]
    }
    return $item
}

proc ::tclutils::tuagrep::search {text pattern args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }

    set result {}
    set n 0
    set count 0
    foreach line [split $text \n] {
        incr n
        if {[LineMatches $line $pattern $opts]} {
            incr count
            if {![dict get $opts -count]} {
                lappend result [FormatMatch {} $n $line $opts]
            }
        }
    }
    if {[dict get $opts -count]} { return $count }
    return $result
}

proc ::tclutils::tuagrep::file {filename pattern args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }

    set fh [open $filename r]
    try {
        fconfigure $fh -translation auto
        set result {}
        set n 0
        set count 0
        set matched 0
        while {[gets $fh line] >= 0} {
            incr n
            if {[LineMatches $line $pattern $opts]} {
                set matched 1
                incr count
                if {![dict get $opts -count]} {
                    lappend result [FormatMatch $filename $n $line $opts]
                }
            }
        }
    } finally {
        close $fh
    }

    if {[dict get $opts -fileswithmatches]} {
        return [expr {$matched ? $filename : ""}]
    }
    if {[dict get $opts -count]} { return $count }
    return $result
}

proc ::tclutils::tuagrep::files {fileList pattern args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }

    set result {}
    foreach filename $fileList {
        if {[dict get $opts -fileswithmatches]} {
            set m [::tclutils::tuagrep::file $filename $pattern {*}$args]
            if {$m ne ""} { lappend result $m }
        } else {
            set localArgs $args
            if {![dict get $opts -filenames]} {
                lappend localArgs -filenames 1
            }
            set matches [::tclutils::tuagrep::file $filename $pattern {*}$localArgs]
            if {[dict get $opts -count]} {
                dict set result $filename $matches
            } else {
                foreach item $matches { lappend result $item }
            }
        }
    }
    return $result
}

package provide tclutils::tuagrep 0.1
