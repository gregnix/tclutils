# tclutils::tustr -- small string helpers that the Tcl core does not provide
# directly (case conversion, padding/centering, prefix/suffix handling,
# slugify, occurrence counting). Pure Tcl, no dependencies. For things the core
# already does well use those instead: [string reverse], [string map], etc.
#
#   tustr::toCamel "my-cool_var"     ;# myCoolVar
#   tustr::toSnake "myCoolVar"       ;# my_cool_var
#   tustr::slugify "Hello, World!" ;# hello-world  (ASCII slug)
#   tustr::truncate $s 20            ;# "..." appended if longer
#   tustr::padLeft 7 4 0             ;# 0007

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tustr {
    namespace export isEmpty truncate padLeft padRight center \
        startsWith endsWith removePrefix removeSuffix splitTrim \
        toCamel toSnake slugify capitalize count
    variable version 0.1
}

proc ::tclutils::tustr::_checkWidth {w} {
    if {![string is integer -strict $w] || $w < 0} {
        return -code error -errorcode {TCLUTILS TUSTR ARG} \
            "width must be a non-negative integer"
    }
}

proc ::tclutils::tustr::isEmpty {s} { return [expr {$s eq ""}] }

proc ::tclutils::tustr::truncate {s maxlen {ellipsis "..."}} {
    if {![string is integer -strict $maxlen] || $maxlen < 0} {
        return -code error -errorcode {TCLUTILS TUSTR ARG} \
            "maxlen must be a non-negative integer"
    }
    if {[string length $s] <= $maxlen} { return $s }
    set keep [expr {$maxlen - [string length $ellipsis]}]
    if {$keep < 0} { set keep 0 }
    return "[string range $s 0 [expr {$keep - 1}]]$ellipsis"
}

proc ::tclutils::tustr::padLeft {s width {char " "}} {
    _checkWidth $width
    set n [expr {$width - [string length $s]}]
    if {$n <= 0} { return $s }
    return "[string repeat $char $n]$s"
}
proc ::tclutils::tustr::padRight {s width {char " "}} {
    _checkWidth $width
    set n [expr {$width - [string length $s]}]
    if {$n <= 0} { return $s }
    return "$s[string repeat $char $n]"
}
proc ::tclutils::tustr::center {s width {char " "}} {
    _checkWidth $width
    set total [expr {$width - [string length $s]}]
    if {$total <= 0} { return $s }
    set left [expr {$total / 2}]
    set right [expr {$total - $left}]
    return "[string repeat $char $left]$s[string repeat $char $right]"
}

proc ::tclutils::tustr::startsWith {s prefix} {
    return [expr {[string first $prefix $s] == 0}]
}
proc ::tclutils::tustr::endsWith {s suffix} {
    set n [string length $suffix]
    if {$n == 0} { return 1 }
    return [expr {[string range $s end-[expr {$n - 1}] end] eq $suffix}]
}
proc ::tclutils::tustr::removePrefix {s prefix} {
    if {$prefix ne "" && [startsWith $s $prefix]} {
        return [string range $s [string length $prefix] end]
    }
    return $s
}
proc ::tclutils::tustr::removeSuffix {s suffix} {
    if {$suffix ne "" && [endsWith $s $suffix]} {
        return [string range $s 0 end-[string length $suffix]]
    }
    return $s
}

# Split on $sep, trim each piece, and drop pieces that become empty.
proc ::tclutils::tustr::splitTrim {s {sep " "}} {
    set out {}
    foreach part [split $s $sep] {
        set t [string trim $part]
        if {$t ne ""} { lappend out $t }
    }
    return $out
}

# Convert snake/kebab/space-delimited words to camelCase.
proc ::tclutils::tustr::toCamel {s} {
    set parts [regexp -all -inline {[A-Za-z0-9]+} $s]
    if {![llength $parts]} { return "" }
    set out [string tolower [lindex $parts 0]]
    foreach p [lrange $parts 1 end] {
        append out [string toupper [string index $p 0]][string tolower [string range $p 1 end]]
    }
    return $out
}

# Convert camelCase / kebab / spaced text to snake_case.
proc ::tclutils::tustr::toSnake {s} {
    regsub -all {([a-z0-9])([A-Z])} $s {\1_\2} s
    regsub -all {[-\s]+} $s {_} s
    return [string tolower $s]
}

# Lowercase ASCII slug: non-alphanumeric runs become a single '-', trimmed.
proc ::tclutils::tustr::slugify {s} {
    set t [string tolower [string trim $s]]
    regsub -all {[^a-z0-9]+} $t {-} t
    return [string trim $t -]
}

proc ::tclutils::tustr::capitalize {s} {
    if {$s eq ""} { return "" }
    return "[string toupper [string index $s 0]][string range $s 1 end]"
}

# Count non-overlapping occurrences of $sub in $s.
proc ::tclutils::tustr::count {s sub} {
    if {$sub eq ""} { return 0 }
    set n 0
    set idx 0
    while {[set idx [string first $sub $s $idx]] >= 0} {
        incr n
        incr idx [string length $sub]
    }
    return $n
}

package provide tclutils::tustr 0.1
