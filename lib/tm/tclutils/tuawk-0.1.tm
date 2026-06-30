# tclutils::tuawk -- awk-style record/field processing
# Description: awk-style record/field processing
# Category: Text · strings/coreutils
# Tcl 8.6+
#
# Brings awk's *model* to Tcl: each record (line) is split into fields, and a
# list of {pattern action} rules is applied. Within patterns and actions the
# fields are available as $0 (whole record), $1..$NF, plus $NR and $NF, and
# `emit` prints (fields joined by OFS, terminated by ORS).
#
# This is NOT an awk language interpreter: patterns are Tcl expressions (or
# /regex/ sugar matched against $0) and actions are Tcl scripts. That keeps it
# pure Tcl and dependency-free while covering the common field-processing jobs.
# Following "missing things show themselves", referencing a field beyond NF is
# an error, not a silent empty string.

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tuawk {
    namespace export run file
    variable version 0.1
    variable counter 0
}

proc ::tclutils::tuawk::_records {text} {
    set lines [split $text \n]
    if {$text ne "" && [lindex $lines end] eq ""} {
        set lines [lrange $lines 0 end-1]
    }
    return $lines
}

proc ::tclutils::tuawk::_splitFields {line fs} {
    if {$fs eq ""} {
        # awk default: split on runs of whitespace, ignoring leading/trailing.
        return [regexp -all -inline {\S+} $line]
    }
    if {[string length $fs] == 1} {
        return [split $line $fs]
    }
    # Multi-character FS is treated as a regular expression.
    set fields {}
    set start 0
    set len [string length $line]
    while {$start <= $len && [regexp -indices -start $start -- $fs $line m]} {
        lassign $m a b
        if {$b < $a} { ;# zero-width match: avoid infinite loop
            if {$start >= $len} break
            incr start
            continue
        }
        lappend fields [string range $line $start [expr {$a - 1}]]
        set start [expr {$b + 1}]
    }
    lappend fields [string range $line $start end]
    return $fields
}

proc ::tclutils::tuawk::_match {ns pat line} {
    set p [string trim $pat]
    if {$p eq ""} { return 1 }
    if {[string length $p] >= 2 && [string index $p 0] eq "/" \
            && [string index $p end] eq "/"} {
        return [regexp -- [string range $p 1 end-1] $line]
    }
    return [namespace eval $ns [list expr $p]]
}

# Run awk-style rules over $text. `rules` is a flat list of pattern/action
# pairs. Special patterns BEGIN and END run before/after the records. An empty
# pattern always matches; an empty action defaults to printing $0.
# Options: -fs "" (default whitespace), -ofs " ", -ors "\n".
proc ::tclutils::tuawk::run {text rules args} {
    variable counter
    set fs ""; set ofs " "; set ors "\n"
    foreach {opt val} $args {
        switch -- $opt {
            -fs  { set fs $val }
            -ofs { set ofs $val }
            -ors { set ors $val }
            default {
                return -code error -errorcode {TCLUTILS TUAWK OPTION} \
                    "unknown option \"$opt\""
            }
        }
    }
    if {[llength $rules] % 2 != 0} {
        return -code error -errorcode {TCLUTILS TUAWK RULES} \
            "rules must be a list of pattern/action pairs"
    }

    set begin {}; set end {}; set main {}
    foreach {pat act} $rules {
        switch -- $pat {
            BEGIN { lappend begin $act }
            END   { lappend end $act }
            default { lappend main [list $pat $act] }
        }
    }

    # Fresh sandbox namespace for field variables and user state.
    set ns ::tclutils::tuawk::sb[incr counter]
    namespace eval $ns {}
    namespace eval $ns [list variable _out ""]
    namespace eval $ns [list variable _ofs $ofs]
    namespace eval $ns [list variable _ors $ors]
    namespace eval $ns {
        proc emit {args} {
            variable _out; variable _ofs; variable _ors
            append _out [join $args $_ofs] $_ors
        }
    }

    try {
        foreach act $begin { namespace eval $ns $act }

        set nr 0
        set lastNF 0
        foreach line [_records $text] {
            incr nr
            set fields [_splitFields $line $fs]
            set nf [llength $fields]
            for {set k 1} {$k <= $lastNF} {incr k} {
                namespace eval $ns [list catch [list unset $k]]
            }
            namespace eval $ns [list set 0 $line]
            namespace eval $ns [list set NR $nr]
            namespace eval $ns [list set NF $nf]
            set k 1
            foreach f $fields {
                namespace eval $ns [list set $k $f]
                incr k
            }
            set lastNF $nf
            foreach rule $main {
                lassign $rule pat act
                if {[_match $ns $pat $line]} {
                    if {[string trim $act] eq ""} { set act {emit $0} }
                    namespace eval $ns $act
                }
            }
        }

        foreach act $end { namespace eval $ns $act }
        set out [set ${ns}::_out]
    } finally {
        namespace delete $ns
    }
    return $out
}

# Run rules over the contents of a file.
proc ::tclutils::tuawk::file {path rules args} {
    set fh [open $path r]
    try {
        fconfigure $fh -translation auto
        set text [read $fh]
    } finally {
        close $fh
    }
    return [run $text $rules {*}$args]
}

package provide tclutils::tuawk 0.1
