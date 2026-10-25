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
    variable version 0.2
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

# Evaluate SCRIPT in the rule context CO (a coroutine whose frame holds the
# fields and user variables). Returns {code result options} as from catch.
proc ::tclutils::tuawk::_eval {co script} {
    return [$co $script]
}

proc ::tclutils::tuawk::_match {co pat line} {
    set p [string trim $pat]
    if {$p eq ""} { return 1 }
    if {[string length $p] >= 2 && [string index $p 0] eq "/" \
            && [string index $p end] eq "/"} {
        return [regexp -- [string range $p 1 end-1] $line]
    }
    lassign [_eval $co [list expr $p]] code res ropts
    if {$code != 0} { return -options $ropts $res }
    return $res
}

# Body of the rule context. It runs as a coroutine inside an apply frame in
# the sandbox namespace, so every variable a rule sets is a local of this one
# frame: it persists across rules and records, and it never resolves to a
# global variable of the same name (Tcl 8.6 namespace resolution).
namespace eval ::tclutils::tuawk {
    variable contextBody {
        set __tuawk_s [yield]
        while 1 {
            set __tuawk_s [yield [list \
                [catch $__tuawk_s __tuawk_s __tuawk_o] \
                $__tuawk_s $__tuawk_o]]
        }
    }
}

# Run awk-style rules over $text. `rules` is a flat list of pattern/action
# pairs. Special patterns BEGIN and END run before/after the records. An empty
# pattern always matches; an empty action defaults to printing $0.
# Options: -fs "" (default whitespace), -ofs " ", -ors "\n".
# Inside an action, `break` skips the remaining rules for the current record
# and `continue` goes on with the next rule.
proc ::tclutils::tuawk::run {text rules args} {
    variable counter
    variable contextBody
    set fs ""; set ofs " "; set ors "\n"
    if {[llength $args] % 2 != 0} {
        return -code error -errorcode {TCLUTILS TUAWK OPTION} \
            "missing value for option \"[lindex $args end]\""
    }
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
            default {
                if {[string trim $act] eq ""} { set act {emit $0} }
                lappend main [list $pat $act]
            }
        }
    }

    # Fresh sandbox namespace for emit, user procs and the rule context.
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
    set co ${ns}::_context
    coroutine $co ::apply [list {} $contextBody $ns]

    try {
        # NR and NF exist from the start (0), as in awk.
        _eval $co {set NR 0; set NF 0}

        foreach act $begin {
            lassign [_eval $co $act] code res ropts
            switch -- $code {
                0 - 2 {}
                1 { return -options $ropts $res }
                3 { break }
                4 { continue }
                default { return -options $ropts $res }
            }
        }

        set nr 0
        set lastNF 0
        foreach line [_records $text] {
            incr nr
            set fields [_splitFields $line $fs]
            set nf [llength $fields]
            set setup {}
            for {set k 1} {$k <= $lastNF} {incr k} {
                lappend setup [list unset -nocomplain $k]
            }
            lappend setup [list set 0 $line] [list set NR $nr] \
                [list set NF $nf]
            set k 1
            foreach f $fields {
                lappend setup [list set $k $f]
                incr k
            }
            _eval $co [join $setup \n]
            set lastNF $nf
            foreach rule $main {
                lassign $rule pat act
                if {[_match $co $pat $line]} {
                    lassign [_eval $co $act] code res ropts
                    switch -- $code {
                        0 - 2 {}
                        1 { return -options $ropts $res }
                        3 { break }
                        4 { continue }
                        default { return -options $ropts $res }
                    }
                }
            }
        }

        foreach act $end {
            lassign [_eval $co $act] code res ropts
            switch -- $code {
                0 - 2 {}
                1 { return -options $ropts $res }
                3 { break }
                4 { continue }
                default { return -options $ropts $res }
            }
        }
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

package provide tclutils::tuawk 0.2
