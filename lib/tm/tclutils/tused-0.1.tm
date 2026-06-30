# tclutils::tused -- small sed-like text replacement/filter routines in pure Tcl
# Description: small sed-like text replacement/filter routines in pure Tcl
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tused {
    namespace export replace substitute delete process processFile script
    variable version 0.1.2
}

proc ::tclutils::tused::ParseOptions {args} {
    set opts [dict create \
        -all 0 \
        -nocase 0 \
        -fixed 0 \
        -inplace 0 \
        -backup "" \
        -encoding utf-8]
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

proc ::tclutils::tused::SubstituteLine {line pattern replacement opts} {
    set all [dict get $opts -all]
    set nocase [dict get $opts -nocase]
    set fixed [dict get $opts -fixed]

    if {$fixed} {
        if {$nocase} {
            return [SubstituteFixedNoCase $line $pattern $replacement $all]
        }
        if {$all} {
            return [string map [list $pattern $replacement] $line]
        }
        set pos [string first $pattern $line]
        if {$pos < 0} { return $line }
        set end [expr {$pos + [string length $pattern] - 1}]
        return [string replace $line $pos $end $replacement]
    }

    set flags [list]
    if {$all} { lappend flags -all }
    if {$nocase} { lappend flags -nocase }
    return [regsub {*}$flags -- $pattern $line $replacement]
}

proc ::tclutils::tused::SubstituteFixedNoCase {line pattern replacement all} {
    if {$pattern eq ""} { return $line }
    set lowerLine [string tolower $line]
    set lowerPattern [string tolower $pattern]
    set start 0
    set out ""
    set plen [string length $pattern]
    while 1 {
        set pos [string first $lowerPattern $lowerLine $start]
        if {$pos < 0} {
            append out [string range $line $start end]
            break
        }
        append out [string range $line $start [expr {$pos - 1}]] $replacement
        set start [expr {$pos + $plen}]
        if {!$all} {
            append out [string range $line $start end]
            break
        }
    }
    return $out
}

proc ::tclutils::tused::LineMatches {line pattern opts} {
    if {[dict get $opts -fixed]} {
        if {[dict get $opts -nocase]} {
            return [expr {[string first [string tolower $pattern] [string tolower $line]] >= 0}]
        }
        return [expr {[string first $pattern $line] >= 0}]
    }
    if {[dict get $opts -nocase]} {
        return [regexp -nocase -- $pattern $line]
    }
    return [regexp -- $pattern $line]
}

proc ::tclutils::tused::ParseAddressToken {token} {
    set token [string trim $token]
    if {$token eq ""} { return [list none] }
    if {$token eq "$"} { return [list last] }
    if {[string is integer -strict $token] && $token > 0} { return [list line $token] }
    if {[string length $token] >= 2 && [string index $token 0] eq "/" && [string index $token end] eq "/"} {
        return [list regex [string range $token 1 end-1]]
    }
    error "unsupported tused address: $token"
}

proc ::tclutils::tused::ParseAddress {addr} {
    set addr [string trim $addr]
    if {$addr eq ""} { return [list none] }
    set parts [split $addr ,]
    if {[llength $parts] == 1} {
        return [list single [ParseAddressToken [lindex $parts 0]]]
    }
    if {[llength $parts] == 2} {
        return [list range [ParseAddressToken [lindex $parts 0]] [ParseAddressToken [lindex $parts 1]] 0]
    }
    error "unsupported tused address range: $addr"
}

proc ::tclutils::tused::AddressTokenMatches {token line lineNo lastNo} {
    switch -- [lindex $token 0] {
        none { return 1 }
        line { return [expr {$lineNo == [lindex $token 1]}] }
        last { return [expr {$lineNo == $lastNo}] }
        regex { return [regexp -- [lindex $token 1] $line] }
        default { error "unknown address token: $token" }
    }
}

proc ::tclutils::tused::RuleApplies {rule line lineNo lastNo} {
    set addr [dict get $rule address]
    switch -- [lindex $addr 0] {
        none { return 1 }
        single { return [AddressTokenMatches [lindex $addr 1] $line $lineNo $lastNo] }
        range {
            set start [lindex $addr 1]
            set end   [lindex $addr 2]
            set active [dict get $rule active]
            if {!$active} {
                if {[AddressTokenMatches $start $line $lineNo $lastNo]} {
                    dict set rule active 1
                    upvar 1 currentRule currentRule
                    set currentRule $rule
                    if {[AddressTokenMatches $end $line $lineNo $lastNo]} {
                        dict set currentRule active 0
                    }
                    return 1
                }
                return 0
            }
            upvar 1 currentRule currentRule
            set currentRule $rule
            if {[AddressTokenMatches $end $line $lineNo $lastNo]} {
                dict set currentRule active 0
            }
            return 1
        }
        default { error "unknown address: $addr" }
    }
}

proc ::tclutils::tused::MakeRule {op args} {
    return [dict create address [list none] active 0 op $op args $args]
}

proc ::tclutils::tused::replace {text pattern replacement args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    set result {}
    foreach line [split $text \n] {
        lappend result [SubstituteLine $line $pattern $replacement $opts]
    }
    return [join $result \n]
}

proc ::tclutils::tused::substitute {line pattern replacement args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    return [SubstituteLine $line $pattern $replacement $opts]
}

proc ::tclutils::tused::delete {text pattern args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }
    set result {}
    foreach line [split $text \n] {
        if {![LineMatches $line $pattern $opts]} {
            lappend result $line
        }
    }
    return [join $result \n]
}

proc ::tclutils::tused::ApplyRule {line rule} {
    if {[llength $rule] > 0 && [lindex $rule 0] in {s d}} {
        set op [lindex $rule 0]
        set args [lrange $rule 1 end]
    } else {
        set op [dict get $rule op]
        set args [dict get $rule args]
    }
    switch -- $op {
        s {
            if {[llength $args] < 2} { error "s rule needs pattern and replacement" }
            set pattern [lindex $args 0]
            set replacement [lindex $args 1]
            set flags [lindex $args 2]
            set sargs {}
            if {[string first g $flags] >= 0} { lappend sargs -all 1 }
            if {[string first i $flags] >= 0} { lappend sargs -nocase 1 }
            return [list 1 [substitute $line $pattern $replacement {*}$sargs]]
        }
        d {
            if {[llength $args] >= 1} {
                set pattern [lindex $args 0]
                if {[regexp -- $pattern $line]} { return [list 0 ""] }
            } else {
                return [list 0 ""]
            }
            return [list 1 $line]
        }
        default {
            error "unknown tused rule: $op"
        }
    }
}

proc ::tclutils::tused::process {text rules} {
    set lines [split $text "\n"]
    set lastNo [llength $lines]
    set result {}
    set ruleList $rules
    set lineNo 0
    foreach line $lines {
        incr lineNo
        set keep 1
        for {set idx 0} {$idx < [llength $ruleList]} {incr idx} {
            set rule [lindex $ruleList $idx]
            if {[llength $rule] > 0 && [lindex $rule 0] in {s d}} {
                set applies 1
            } else {
                set currentRule $rule
                set applies [RuleApplies $rule $line $lineNo $lastNo]
                set ruleList [lreplace $ruleList $idx $idx $currentRule]
            }
            if {$applies} {
                lassign [ApplyRule $line [lindex $ruleList $idx]] keep line
                if {!$keep} { break }
            }
        }
        if {$keep} { lappend result $line }
    }
    return [join $result "\n"]
}

proc ::tclutils::tused::ParseScriptLine {line} {
    set addr ""
    set cmd $line
    set first [string index $line 0]
    if {$first eq "/"} {
        set end [string first / $line 1]
        if {$end < 0} { error "bad address in tused script line: $line" }
        set addr [string range $line 0 $end]
        set rest [string range $line [expr {$end + 1}] end]
        if {[string index $rest 0] eq ","} {
            set rest2 [string range $rest 1 end]
            if {[string index $rest2 0] eq "/"} {
                set end2 [string first / $rest2 1]
                if {$end2 < 0} { error "bad address range in tused script line: $line" }
                append addr , [string range $rest2 0 $end2]
                set cmd [string range $rest2 [expr {$end2 + 1}] end]
            } elseif {[regexp {^([0-9]+|\$)(.*)$} $rest2 -> second tail]} {
                append addr , $second
                set cmd $tail
            }
        } else {
            set cmd $rest
        }
    } elseif {[regexp {^([0-9]+|\$)(,([0-9]+|\$|/[^/]*/))?(.*)$} $line -> first dummy second tail]} {
        set addr $first
        if {$second ne ""} { append addr , $second }
        set cmd $tail
    }
    set cmd [string trim $cmd]
    if {[regexp {^s/(.*)/(.*)/([A-Za-z]*)$} $cmd -> pattern replacement flags]} {
        set rule [MakeRule s $pattern $replacement $flags]
    } elseif {[regexp {^d(?:/(.*)/)?$} $cmd -> pattern]} {
        if {[info exists pattern] && $pattern ne ""} {
            set rule [MakeRule d $pattern]
        } else {
            set rule [MakeRule d]
        }
    } else {
        error "unsupported tused script line: $line"
    }
    if {$addr ne ""} { dict set rule address [ParseAddress $addr] }
    return $rule
}

proc ::tclutils::tused::processFile {infile outfile rules args} {
    lassign [ParseOptions {*}$args] rest opts
    if {[llength $rest] != 0} { error "unexpected arguments: $rest" }

    set enc [dict get $opts -encoding]
    set in [open $infile r]
    fconfigure $in -encoding $enc -translation auto
    set text [read $in]
    close $in

    set result [process $text $rules]

    if {[dict get $opts -inplace]} {
        set backup [dict get $opts -backup]
        if {$backup ne ""} {
            file copy -force -- $infile ${infile}${backup}
        }
        set outfile $infile
    }

    set out [open $outfile w]
    fconfigure $out -encoding $enc -translation lf
    puts -nonewline $out $result
    close $out
    return $outfile
}

proc ::tclutils::tused::script {text scriptText} {
    set rules {}
    foreach raw [split $scriptText "\n"] {
        set line [string trim $raw]
        if {$line eq "" || [string match #* $line]} { continue }
        lappend rules [ParseScriptLine $line]
    }
    return [process $text $rules]
}

package provide tclutils::tused 0.1
