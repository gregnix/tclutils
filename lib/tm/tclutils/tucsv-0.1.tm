# tclutils::tucsv -- small CSV helpers
# Tcl 8.6+, pure Tcl

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucsv {
    namespace export parseLine joinLine parse text file dicts writeFile
}

proc ::tclutils::tucsv::_parseOptions {defaults args} {
    return [::tclutils::common::parseOptions $defaults {*}$args]
}

proc ::tclutils::tucsv::_oneChar {value optionName} {
    if {[string length $value] != 1} {
        return -code error -errorcode [list TCLUTILS TUCSV OPTION $optionName] "$optionName must be exactly one character"
    }
    return $value
}

proc ::tclutils::tucsv::parseLine {line args} {
    set opts [_parseOptions [dict create -delimiter , -quote \" -trim 0 -strict 1] {*}$args]
    set delimiter [_oneChar [dict get $opts -delimiter] -delimiter]
    set quote [_oneChar [dict get $opts -quote] -quote]
    set trim [::tclutils::common::ensureBoolean [dict get $opts -trim] -trim]
    set strict [::tclutils::common::ensureBoolean [dict get $opts -strict] -strict]

    set fields {}
    set field ""
    set inQuote 0
    set i 0
    set n [string length $line]

    while {$i < $n} {
        set ch [string index $line $i]
        if {$inQuote} {
            if {$ch eq $quote} {
                set next [expr {$i + 1}]
                if {$next < $n && [string index $line $next] eq $quote} {
                    append field $quote
                    incr i 2
                    continue
                }
                set inQuote 0
                incr i
                continue
            }
            append field $ch
            incr i
            continue
        }

        if {$ch eq $quote && $field eq ""} {
            set inQuote 1
            incr i
            continue
        }
        if {$ch eq $delimiter} {
            if {$trim} { set field [string trim $field] }
            lappend fields $field
            set field ""
            incr i
            continue
        }
        append field $ch
        incr i
    }

    if {$inQuote && $strict} {
        return -code error -errorcode {TCLUTILS TUCSV QUOTE} "unterminated quoted field"
    }
    if {$trim} { set field [string trim $field] }
    lappend fields $field
    return $fields
}

proc ::tclutils::tucsv::joinLine {fields args} {
    set opts [_parseOptions [dict create -delimiter , -quote \" -alwaysQuote 0] {*}$args]
    set delimiter [_oneChar [dict get $opts -delimiter] -delimiter]
    set quote [_oneChar [dict get $opts -quote] -quote]
    set alwaysQuote [::tclutils::common::ensureBoolean [dict get $opts -alwaysQuote] -alwaysQuote]

    set out {}
    foreach field $fields {
        set s $field
        set mustQuote $alwaysQuote
        if {[string first $delimiter $s] >= 0 || [string first $quote $s] >= 0 || [string first "\n" $s] >= 0 || [string first "\r" $s] >= 0} {
            set mustQuote 1
        }
        if {$mustQuote} {
            set escaped [string map [list $quote $quote$quote] $s]
            lappend out "$quote$escaped$quote"
        } else {
            lappend out $s
        }
    }
    return [join $out $delimiter]
}

proc ::tclutils::tucsv::parse {data args} {
    set opts [_parseOptions [dict create -delimiter , -quote \" -trim 0 -skipEmpty 0 -strict 1] {*}$args]
    set delimiter [dict get $opts -delimiter]
    set quote [dict get $opts -quote]
    set trim [dict get $opts -trim]
    set skipEmpty [::tclutils::common::ensureBoolean [dict get $opts -skipEmpty] -skipEmpty]
    set strict [::tclutils::common::ensureBoolean [dict get $opts -strict] -strict]

    # Strip a leading UTF-8 BOM if present.
    if {[string index $data 0] eq "\uFEFF"} { set data [string range $data 1 end] }

    # Records can contain newlines inside quoted fields.  Build logical records first.
    set records {}
    set current ""
    set inQuote 0
    set i 0
    set n [string length $data]
    while {$i < $n} {
        set ch [string index $data $i]
        if {$ch eq $quote} {
            set next [expr {$i + 1}]
            if {$inQuote && $next < $n && [string index $data $next] eq $quote} {
                append current $ch$quote
                incr i 2
                continue
            }
            set inQuote [expr {!$inQuote}]
            append current $ch
            incr i
            continue
        }
        if {!$inQuote && ($ch eq "\n" || $ch eq "\r")} {
            if {$ch eq "\r" && $i + 1 < $n && [string index $data [expr {$i + 1}]] eq "\n"} {
                incr i
            }
            if {!($skipEmpty && $current eq "")} {
                lappend records $current
            }
            set current ""
            incr i
            continue
        }
        append current $ch
        incr i
    }
    if {$inQuote && $strict} {
        return -code error -errorcode {TCLUTILS TUCSV QUOTE} "unterminated quoted field"
    }
    if {$current ne ""} {
        lappend records $current
    }

    set rows {}
    foreach rec $records {
        lappend rows [parseLine $rec -delimiter $delimiter -quote $quote -trim $trim -strict $strict]
    }
    return $rows
}

proc ::tclutils::tucsv::text {rows args} {
    set opts [_parseOptions [dict create -delimiter , -quote \" -alwaysQuote 0 -newline \n] {*}$args]
    set out {}
    foreach row $rows {
        lappend out [joinLine $row -delimiter [dict get $opts -delimiter] -quote [dict get $opts -quote] -alwaysQuote [dict get $opts -alwaysQuote]]
    }
    return [join $out [dict get $opts -newline]]
}

proc ::tclutils::tucsv::file {path args} {
    return [parse [::tclutils::common::readFile $path] {*}$args]
}

proc ::tclutils::tucsv::dicts {rows args} {
    set opts [_parseOptions [dict create -headers {}] {*}$args]
    set headers [dict get $opts -headers]
    if {$headers eq {}} {
        if {[llength $rows] == 0} { return {} }
        set headers [lindex $rows 0]
        set rows [lrange $rows 1 end]
    }
    set out {}
    foreach row $rows {
        set d {}
        for {set i 0} {$i < [llength $headers]} {incr i} {
            dict set d [lindex $headers $i] [lindex $row $i]
        }
        lappend out $d
    }
    return $out
}

proc ::tclutils::tucsv::writeFile {path rows args} {
    ::tclutils::common::writeFile $path [text $rows {*}$args]
    return $path
}

package provide tclutils::tucsv 0.1
