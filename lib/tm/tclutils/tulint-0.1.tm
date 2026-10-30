# tclutils::tulint -- static checks for Tcl sources, as data
# Description: static checks for Tcl sources: rules by name, findings as dicts, no output
# Category: System · runtime
#
# A small engine for checks over Tcl files and a first set of rules. The
# rule names are the identifiers of the book "Tcl/Tk Quality" (ENC-1,
# TST-3 ...); every finding says which entry explains it.
#
#   ::tclutils::tulint::check paths ?-rules names? ?-exclude patterns?
#       -> list of findings {file F line N rule R severity S message M}
#   ::tclutils::tulint::checkText text ?-file name? ?-rules names?
#   ::tclutils::tulint::rules                 -> list of {name severity description}
#   ::tclutils::tulint::register name severity description cmd
#   ::tclutils::tulint::unregister name
#   ::tclutils::tulint::summary findings      -> {error N warning N info N}
#   ::tclutils::tulint::format findings ?-format text|json?
#
# The module prints nothing and never exits; bin/tulint.tcl is the command
# line. A rule is a command called as {*}cmd file text and returns a list
# of {line message} pairs. Other packages register their own rules (for
# example project conventions); tclutils brings only general ones:
#
#   ENC-1  error-free under Tcl 8.6 only with "tclsh -encoding utf-8":
#          non-ASCII characters in a *.test file          (warning)
#   ENC-2  pkgIndex.tcl: source without -encoding         (error)
#   ENC-3  non-ASCII characters outside comments in a *.tcl script, also
#          tests/all.tcl (8.6 reads it in the system encoding)  (warning)
#   TST-3  the same test name twice in a file; two branches of one if or
#          switch are alternatives and do not count       (error)
#   DAT-2  open ... w (or wb, w+, TRUNC) in a module or script: the target
#          is empty at once, a failed write loses the old file; write
#          through common::replaceFile. A path word containing "tmp" is
#          taken as a temporary file and not reported   (info)
#
# A file that is not valid UTF-8 is the finding FILE (error); its rules
# are not run.
#
# Suppressing: "# tulint: ignore RULE ?RULE ...?" on a line of its own
# applies to the next line, ";# tulint: ignore RULE" at the end of a line
# to that line. Only the named rules are suppressed.
#
# Namespace: ::tclutils::tulint   Package: tclutils::tulint 0.1
# Errors:    {TCLUTILS TULINT <REASON>}  REASON in OPTION RULE SEVERITY
#            (a file that cannot be read raises the error of open)
# Requires:  Tcl 8.6-, tclutils::tuiconv 0.2, tclutils::tujson 0.1

package require Tcl 8.6-
package require tclutils::tuiconv 0.2
package require tclutils::tujson 0.1

namespace eval ::tclutils::tulint {
    namespace export check checkText checkFile rules register unregister \
        summary format
    # name -> {severity description cmd}
    variable registry [dict create]
}

proc ::tclutils::tulint::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TULINT $reason] $msg
}

# Options: a dict of defaults, the list given; unknown keys and a missing
# value are errors (a typo must not be ignored).
proc ::tclutils::tulint::_options {defaults arglist} {
    if {[llength $arglist] % 2} {
        _err OPTION "missing value for option \"[lindex $arglist end]\""
    }
    set o $defaults
    foreach {k v} $arglist {
        if {![dict exists $defaults $k]} {
            _err OPTION "unknown option \"$k\": must be [join [lsort [dict keys $defaults]] {, }]"
        }
        dict set o $k $v
    }
    return $o
}

# --- registry ---------------------------------------------------------------

proc ::tclutils::tulint::register {name severity description cmd} {
    variable registry
    if {$name eq "" || [regexp {\s} $name]} {
        _err RULE "rule name must be one word, got \"$name\""
    }
    if {$severity ni {error warning info}} {
        _err SEVERITY "bad severity \"$severity\": must be error, warning or info"
    }
    dict set registry $name [list $severity $description $cmd]
    return $name
}

proc ::tclutils::tulint::unregister {name} {
    variable registry
    if {![dict exists $registry $name]} { _err RULE "unknown rule \"$name\"" }
    dict unset registry $name
    return
}

proc ::tclutils::tulint::rules {} {
    variable registry
    set out {}
    foreach name [lsort -dictionary [dict keys $registry]] {
        lassign [dict get $registry $name] sev desc
        lappend out [dict create name $name severity $sev description $desc]
    }
    return $out
}

proc ::tclutils::tulint::_ruleNames {names} {
    variable registry
    if {$names eq "all"} { return [lsort -dictionary [dict keys $registry]] }
    foreach n $names {
        if {![dict exists $registry $n]} {
            _err RULE "unknown rule \"$n\": must be one of [join [lsort -dictionary [dict keys $registry]] {, }]"
        }
    }
    return $names
}

# --- running ----------------------------------------------------------------

# Lines with a suppression: dict line -> list of rule names.
proc ::tclutils::tulint::_ignores {lines} {
    set ign [dict create]
    set n 0
    foreach l $lines {
        incr n
        if {[regexp {#\s*tulint:\s*ignore\s+(.*)$} $l -> what]} {
            set target [expr {[string match "#*" [string trimleft $l]] ? $n + 1 : $n}]
            foreach r [regexp -all -inline {\S+} $what] { dict lappend ign $target $r }
        }
    }
    return $ign
}

proc ::tclutils::tulint::_lines {text} {
    return [split [string map [list \r\n \n \r \n] $text] \n]
}

proc ::tclutils::tulint::checkText {text args} {
    variable registry
    set o [_options {-file "" -rules all} $args]
    set file [dict get $o -file]
    set names [_ruleNames [dict get $o -rules]]
    set ign [_ignores [_lines $text]]
    set out {}
    foreach name $names {
        lassign [dict get $registry $name] sev desc cmd
        foreach hit [{*}$cmd $file $text] {
            lassign $hit line msg
            if {[dict exists $ign $line] && $name in [dict get $ign $line]} continue
            lappend out [dict create file $file line $line rule $name \
                severity $sev message $msg]
        }
    }
    return [lsort -command [namespace which _byPlace] $out]
}

proc ::tclutils::tulint::_byPlace {a b} {
    set c [string compare [dict get $a file] [dict get $b file]]
    if {$c} { return $c }
    set c [expr {[dict get $a line] - [dict get $b line]}]
    if {$c} { return [expr {$c < 0 ? -1 : 1}] }
    return [string compare [dict get $a rule] [dict get $b rule]]
}

proc ::tclutils::tulint::checkFile {path args} {
    set o [_options {-rules all} $args]
    if {[catch {::tclutils::tuiconv::readFile $path utf-8} text opts]} {
        if {[lrange [dict get $opts -errorcode] 0 2] ne {TCLUTILS TUICONV INVALID}} {
            return -options $opts $text
        }
        return [list [dict create file $path line 1 rule FILE severity error \
            message "not valid UTF-8 ($text)"]]
    }
    return [checkText $text -file $path -rules [dict get $o -rules]]
}

# Files below PATH: *.tcl, *.tm, *.test; directories .git and nogit and
# every path matching one of EXCLUDE (glob on the full path) are skipped.
proc ::tclutils::tulint::_collect {path exclude} {
    foreach p $exclude {
        if {[string match $p $path]} { return {} }
    }
    if {[file isdirectory $path]} {
        if {[file tail $path] in {.git nogit}} { return {} }
        set out {}
        foreach f [lsort [glob -nocomplain -directory $path *]] {
            lappend out {*}[_collect $f $exclude]
        }
        return $out
    }
    if {[file extension $path] in {.tcl .tm .test}} { return [list $path] }
    return {}
}

proc ::tclutils::tulint::check {paths args} {
    set o [_options {-rules all -exclude {}} $args]
    set names [_ruleNames [dict get $o -rules]]
    set out {}
    foreach p $paths {
        if {![file exists $p]} { _err OPTION "no such file or directory: $p" }
        foreach f [_collect $p [dict get $o -exclude]] {
            lappend out {*}[checkFile $f -rules $names]
        }
    }
    return $out
}

proc ::tclutils::tulint::summary {findings} {
    set s [dict create error 0 warning 0 info 0]
    foreach f $findings { dict incr s [dict get $f severity] }
    return $s
}

proc ::tclutils::tulint::format {findings args} {
    set o [_options {-format text} $args]
    switch -- [dict get $o -format] {
        text {
            set out {}
            foreach f $findings {
                lappend out "[dict get $f file]:[dict get $f line]: [dict get $f severity] [dict get $f rule]: [dict get $f message]"
            }
            return [join $out \n]
        }
        json {
            set J ::tclutils::tujson
            set items {}
            foreach f $findings {
                lappend items [${J}::obj [list \
                    file [${J}::str [dict get $f file]] \
                    line [${J}::num [dict get $f line]] \
                    rule [${J}::str [dict get $f rule]] \
                    severity [${J}::str [dict get $f severity]] \
                    message [${J}::str [dict get $f message]]]]
            }
            return [${J}::toJson [${J}::arr $items]]
        }
        default { _err OPTION "bad format \"[dict get $o -format]\": must be text or json" }
    }
}

# --- source helpers ---------------------------------------------------------

# Complete commands of a script: list of {firstLine text}. A comment is a
# command of its own and starts with "#".
proc ::tclutils::tulint::_commands {text {line0 1}} {
    set out {}
    set cur ""
    set start 0
    set n [expr {$line0 - 1}]
    foreach l [_lines $text] {
        incr n
        if {$cur eq ""} {
            if {[string trim $l] eq ""} continue
            set start $n
            set cur $l
        } else {
            append cur \n $l
        }
        if {[info complete $cur\n]} {
            lappend out [list $start $cur]
            set cur ""
        }
    }
    if {$cur ne ""} { lappend out [list $start $cur] }
    return $out
}

# Line of the first occurrence of WORD inside the command CMD starting at
# line START (the body of a braced word starts on the line of its brace).
proc ::tclutils::tulint::_wordLine {cmd word start} {
    set i [string first $word $cmd]
    if {$i < 0} { return $start }
    return [expr {$start + [regexp -all \n [string range $cmd 0 $i-1]]}]
}

proc ::tclutils::tulint::_isTestFile {file} {
    return [expr {[file extension $file] eq ".test"}]
}

# Line numbers (1-based) that hold a non-ASCII character outside a comment
# line. A trailing ";# ..." comment counts as comment.
proc ::tclutils::tulint::_nonAsciiLines {text} {
    set out {}
    set n 0
    foreach l [_lines $text] {
        incr n
        if {[string match "#*" [string trimleft $l]]} continue
        set code $l
        if {[set i [string first ";#" $code]] >= 0} { set code [string range $code 0 $i-1] }
        if {[regexp {[^\x00-\x7f]} $code]} { lappend out $n }
    }
    return $out
}

# --- rules ------------------------------------------------------------------

proc ::tclutils::tulint::_ruleEnc1 {file text} {
    if {![_isTestFile $file]} { return {} }
    set out {}
    foreach n [_nonAsciiLines $text] {
        lappend out [list $n "non-ASCII character in a test file: under Tcl 8.6 safe only when the runner starts it with -encoding utf-8, or write it as \\uXXXX"]
    }
    return $out
}

proc ::tclutils::tulint::_ruleEnc2 {file text} {
    if {[file tail $file] ne "pkgIndex.tcl"} { return {} }
    set out {}
    foreach c [_commands $text] {
        lassign $c start cmd
        if {[string match "#*" $cmd]} continue
        set pos 0
        while {[regexp -start $pos -indices {\msource\s+(\S+)} $cmd all arg]} {
            set pos [expr {[lindex $all 1] + 1}]
            if {[string range $cmd {*}$arg] eq "-encoding"} continue
            set line [expr {$start + [regexp -all \n [string range $cmd 0 [lindex $all 0]-1]]}]
            lappend out [list $line "source without -encoding: Tcl 8.6 reads the file in the system encoding; use \[list source -encoding utf-8 ...\]"]
        }
    }
    return $out
}

proc ::tclutils::tulint::_ruleEnc3 {file text} {
    # tests/all.tcl and helper scripts a test sources are read in the system
    # encoding too, so they count
    if {[file extension $file] ne ".tcl" || [file tail $file] eq "pkgIndex.tcl"} {
        return {}
    }
    set out {}
    foreach n [_nonAsciiLines $text] {
        lappend out [list $n "non-ASCII character in a script: Tcl 8.6 reads it in the system encoding (cp1252 on Windows); write it as \\uXXXX or start the script with -encoding utf-8"]
    }
    return $out
}

# Test definitions of a script, descending into braced script words.
# Each definition: {name line branches}; branches is a list of
# {ifId branchIndex} for the if/switch branches it sits in.
proc ::tclutils::tulint::_tests {text line0 branches counterVar} {
    upvar 1 $counterVar counter
    set out {}
    foreach c [_commands $text $line0] {
        lassign $c start cmd
        if {[string match "#*" $cmd]} continue
        if {[catch {llength $cmd} len] || $len == 0} continue
        set w0 [lindex $cmd 0]
        if {$w0 in {test tcltest::test ::tcltest::test}} {
            if {$len >= 2} { lappend out [list [lindex $cmd 1] $start $branches] }
            continue
        }
        # bodies that are alternatives of each other
        set alts {}
        if {$w0 eq "if"} {
            set alts [_ifBodies $cmd]
        } elseif {$w0 eq "switch"} {
            set alts [_switchBodies $cmd]
        }
        if {[llength $alts]} {
            set id [incr counter]
            set k 0
            foreach body $alts {
                lappend out {*}[_tests $body [_wordLine $cmd $body $start] \
                    [linsert $branches end [list $id $k]] counter]
                incr k
            }
            continue
        }
        foreach word [lrange $cmd 1 end] {
            if {[string first \n $word] >= 0 && [info complete $word]} {
                lappend out {*}[_tests $word [_wordLine $cmd $word $start] $branches counter]
            }
        }
    }
    return $out
}

proc ::tclutils::tulint::_ifBodies {cmd} {
    set words [lrange $cmd 1 end]
    set bodies {}
    set i 1  ;# skip the condition
    while {$i < [llength $words]} {
        if {[lindex $words $i] eq "then"} { incr i }
        lappend bodies [lindex $words $i]
        incr i
        set kw [lindex $words $i]
        if {$kw eq "elseif"} {
            incr i 2
        } elseif {$kw eq "else"} {
            incr i
        } elseif {$i < [llength $words]} {
            # an else body without the keyword
        } else {
            break
        }
    }
    return $bodies
}

proc ::tclutils::tulint::_switchBodies {cmd} {
    set words [lrange $cmd 1 end]
    set i 0
    while {$i < [llength $words] && [string match -* [lindex $words $i]]} {
        set opt [lindex $words $i]
        incr i
        if {$opt eq "--"} break
        if {$opt in {-matchvar -indexvar}} { incr i }
    }
    incr i  ;# the string
    set rest [lrange $words $i end]
    if {[llength $rest] == 1} { set rest [lindex $rest 0] }
    set bodies {}
    foreach {pat body} $rest {
        if {$body ne "-"} { lappend bodies $body }
    }
    return $bodies
}

# Two definitions exclude each other when they sit in different branches
# of the same if or switch.
proc ::tclutils::tulint::_exclusive {a b} {
    foreach x $a {
        lassign $x id k
        foreach y $b {
            lassign $y id2 k2
            if {$id == $id2 && $k != $k2} { return 1 }
        }
    }
    return 0
}

proc ::tclutils::tulint::_ruleTst3 {file text} {
    set counter 0
    set seen [dict create]
    set out {}
    foreach def [_tests $text 1 {} counter] {
        lassign $def name line br
        if {[dict exists $seen $name]} {
            foreach prev [dict get $seen $name] {
                lassign $prev pline pbr
                if {![_exclusive $br $pbr]} {
                    lappend out [list $line "test name \"$name\" already used in line $pline"]
                    break
                }
            }
        }
        dict lappend seen $name [list $line $br]
    }
    return $out
}

# open with a truncating mode, outside comments; *.test files are skipped,
# they write their fixtures this way on purpose
proc ::tclutils::tulint::_ruleDat2 {file text} {
    if {[_isTestFile $file] || [file extension $file] ni {.tcl .tm}} { return {} }
    set re {\[open\s+(\S+)\s+(?:"?w[b+]?"?|\{w[b+]?\}|\{[^\}]*TRUNC[^\}]*\})[\s\]]}
    set out {}
    set n 0
    foreach l [_lines $text] {
        incr n
        if {[string match "#*" [string trimleft $l]]} continue
        set code $l
        if {[set i [string first ";#" $code]] >= 0} { set code [string range $code 0 $i-1] }
        foreach {all path} [regexp -all -inline $re $code] {
            if {[string match -nocase *tmp* $path]} continue
            lappend out [list $n "open $path truncates the file at once: a failed write leaves it empty; write through common::replaceFile (temporary file, then rename)"]
            break
        }
    }
    return $out
}

::tclutils::tulint::register DAT-2 info \
    "open truncates the target before the data is written" ::tclutils::tulint::_ruleDat2
::tclutils::tulint::register ENC-1 warning \
    "non-ASCII characters in a test file" ::tclutils::tulint::_ruleEnc1
::tclutils::tulint::register ENC-2 error \
    "pkgIndex.tcl sources a file without -encoding" ::tclutils::tulint::_ruleEnc2
::tclutils::tulint::register ENC-3 warning \
    "non-ASCII characters in a script outside comments" ::tclutils::tulint::_ruleEnc3
::tclutils::tulint::register TST-3 error \
    "the same test name twice in a file" ::tclutils::tulint::_ruleTst3

package provide tclutils::tulint 0.1
