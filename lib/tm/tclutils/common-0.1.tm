# tclutils::common -- shared helpers for tclutils modules
# Tcl 8.6+

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::common {
    namespace export readFile readBinaryFile writeFile splitLines splitDelimited parseOptions ensureBoolean ensurePositiveInteger
    variable version 0.1
}

proc ::tclutils::common::readFile {path} {
    set fh [open $path r]
    try {
        fconfigure $fh -translation auto
        return [read $fh]
    } finally {
        close $fh
    }
}

proc ::tclutils::common::readBinaryFile {path} {
    set fh [open $path rb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        return [read $fh]
    } finally {
        close $fh
    }
}

proc ::tclutils::common::writeFile {path data {mode w}} {
    set fh [open $path $mode]
    try {
        fconfigure $fh -translation auto
        puts -nonewline $fh $data
    } finally {
        close $fh
    }
    return $path
}

proc ::tclutils::common::splitLines {text} {
    if {$text eq ""} { return {} }
    set lines [split $text \n]
    if {[string index $text end] eq "\n"} {
        set lines [lrange $lines 0 end-1]
    }
    return $lines
}

proc ::tclutils::common::splitDelimited {line delimiter} {
    if {$delimiter eq ""} {
        return -code error -errorcode {TCLUTILS COMMON DELIMITER} "delimiter must not be empty"
    }
    if {[string length $delimiter] == 1} {
        return [split $line $delimiter]
    }
    set out {}
    set start 0
    set dlen [string length $delimiter]
    while 1 {
        set idx [string first $delimiter $line $start]
        if {$idx < 0} {
            lappend out [string range $line $start end]
            break
        }
        lappend out [string range $line $start [expr {$idx - 1}]]
        set start [expr {$idx + $dlen}]
    }
    return $out
}

proc ::tclutils::common::parseOptions {defaults args} {
    set opts $defaults
    set i 0
    while {$i < [llength $args]} {
        set opt [lindex $args $i]
        if {![dict exists $opts $opt]} {
            return -code error -errorcode [list TCLUTILS COMMON OPTION $opt] "unknown option \"$opt\""
        }
        incr i
        if {$i >= [llength $args]} {
            return -code error -errorcode [list TCLUTILS COMMON OPTION $opt] "missing value for option \"$opt\""
        }
        dict set opts $opt [lindex $args $i]
        incr i
    }
    return $opts
}

proc ::tclutils::common::ensureBoolean {value optionName} {
    if {![string is boolean -strict $value]} {
        return -code error -errorcode [list TCLUTILS COMMON BOOLEAN $optionName] "$optionName requires a boolean value"
    }
    return [expr {$value ? 1 : 0}]
}

proc ::tclutils::common::ensurePositiveInteger {value what} {
    if {![string is integer -strict $value] || $value < 1} {
        return -code error -errorcode [list TCLUTILS COMMON INTEGER $what] "$what must be a positive integer"
    }
    return $value
}

package provide tclutils::common 0.1
