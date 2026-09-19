# tclutils::common -- shared helpers for tclutils modules
# Description: shared helpers for tclutils modules
# Category: System · runtime
# Tcl 8.6+

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::common {
    namespace export readFile readBinaryFile writeFile splitLines splitDelimited parseOptions ensureBoolean ensurePositiveInteger ensureOneOf
    variable version 0.2
}

# readFile path ?-encoding enc?
# Without -encoding the channel uses the SYSTEM encoding (utf-8 on Linux,
# usually cp1252 under Tcl 8.6 on Windows). Pass -encoding utf-8 when the file
# is known to be UTF-8 and non-ASCII text is compared or displayed.
proc ::tclutils::common::readFile {path args} {
    set o [parseOptions {-encoding ""} {*}$args]
    set fh [open $path r]
    try {
        fconfigure $fh -translation auto
        if {[dict get $o -encoding] ne ""} {
            fconfigure $fh -encoding [dict get $o -encoding]
        }
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

# writeFile path data ?mode? ?-encoding enc?
# mode is the open access mode (default w). Without -encoding the channel uses
# the system encoding, as readFile does.
proc ::tclutils::common::writeFile {path data args} {
    set mode w
    if {[llength $args] % 2 == 1} {
        set args [lassign $args mode]
    }
    set o [parseOptions {-encoding ""} {*}$args]
    set fh [open $path $mode]
    try {
        fconfigure $fh -translation auto
        if {[dict get $o -encoding] ne ""} {
            fconfigure $fh -encoding [dict get $o -encoding]
        }
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

# parseOptions defaults ?option value ...?
# DEFAULTS is a dict of the allowed options and their default values. An
# unknown option is an error whose message lists the known ones, so the answer
# stands next to the question:
#     unknown option "-typ"
#     Known: -type -timeout
proc ::tclutils::common::parseOptions {defaults args} {
    set opts $defaults
    set i 0
    while {$i < [llength $args]} {
        set opt [lindex $args $i]
        if {![dict exists $opts $opt]} {
            return -code error -errorcode [list TCLUTILS COMMON OPTION $opt] \
                "unknown option \"$opt\"\nKnown: [join [dict keys $defaults] { }]"
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

# ensureOneOf value allowed what
# Return VALUE if it is one of ALLOWED (exact match), else raise an error that
# lists the allowed values next to the rejected one:
#     unknown document type: quatsch
#     Known: invoice delivery_note warranty
# errorcode {TCLUTILS COMMON VALUE <what>}. WHAT names the kind of value in
# the message ("document type", "-style"). The answer stands next to the
# question -- a bare "invalid value" sends the reader to the source.
proc ::tclutils::common::ensureOneOf {value allowed what} {
    if {$value in $allowed} { return $value }
    return -code error -errorcode [list TCLUTILS COMMON VALUE $what] \
        "unknown $what: $value\nKnown: [join $allowed { }]"
}

package provide tclutils::common 0.2
