# tclutils::tustr -- small string helpers that the Tcl core does not provide
# Description: small string helpers the Tcl core lacks (case, padding/centering, affixes, slug, graphemes)
# Category: Text · strings/coreutils
# directly (case conversion, padding/centering, prefix/suffix handling,
# slugify, occurrence counting). Pure Tcl, no dependencies. For things the core
# already does well use those instead: [string reverse], [string map], etc.
#
#   tustr::toCamel "my-cool_var"     ;# myCoolVar
#   tustr::toSnake "myCoolVar"       ;# my_cool_var
#   tustr::slugify "Hello, World!" ;# hello-world  (ASCII slug)
#   tustr::truncate $s 20            ;# "..." appended if longer
#   tustr::padLeft 7 4 0             ;# 0007
#   tustr::graphemes "e\u0301x"      ;# 2 items: "e+accent" and "x"

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tustr {
    namespace export isEmpty truncate padLeft padRight center \
        startsWith endsWith removePrefix removeSuffix splitTrim \
        toCamel toSnake slugify capitalize count \
        graphemes isPrintable
    variable version 0.2
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

# ---------------------------------------------------------------------------
# Graphemes: user-perceived characters (simplified UAX #29).
#
# Kept together: base + combining marks / variation selectors / skin-tone
# modifiers / emoji tag characters, ZWJ sequences (base ZWJ base ...),
# regional-indicator pairs (flags), and CR LF. Not covered: Hangul syllable
# composition, Indic conjuncts, the full Extended_Pictographic rule.
#
# Under Tcl 8.6 a character beyond U+FFFF arrives as two surrogates (from a
# channel or encoding convertfrom). They are joined into one code point first,
# so a flag or a ZWJ emoji splits the same under 8.6 and 9.
# ---------------------------------------------------------------------------

# Returns a list of {char codepoint} with surrogate pairs merged.
proc ::tclutils::tustr::_codepoints {s} {
    set out {}
    set chars [split $s ""]
    set n [llength $chars]
    for {set i 0} {$i < $n} {incr i} {
        set c [lindex $chars $i]
        scan $c %c cp
        if {$cp >= 0xD800 && $cp <= 0xDBFF && $i + 1 < $n} {
            set c2 [lindex $chars [expr {$i + 1}]]
            scan $c2 %c lo
            if {$lo >= 0xDC00 && $lo <= 0xDFFF} {
                set cp [expr {0x10000 + (($cp - 0xD800) << 10) + ($lo - 0xDC00)}]
                append c $c2
                incr i
            }
        }
        lappend out $c $cp
    }
    return $out
}

proc ::tclutils::tustr::_extend {cp} {
    expr {
        ($cp >= 0x0300 && $cp <= 0x036F) || ($cp >= 0x0483 && $cp <= 0x0489) ||
        ($cp >= 0x0591 && $cp <= 0x05BD) || ($cp >= 0x0610 && $cp <= 0x061A) ||
        ($cp >= 0x064B && $cp <= 0x065F) || ($cp >= 0x1AB0 && $cp <= 0x1AFF) ||
        ($cp >= 0x1DC0 && $cp <= 0x1DFF) || ($cp >= 0x20D0 && $cp <= 0x20FF) ||
        ($cp >= 0xFE00 && $cp <= 0xFE0F) || ($cp >= 0x1F3FB && $cp <= 0x1F3FF) ||
        ($cp >= 0xE0020 && $cp <= 0xE007F) || ($cp >= 0xE0100 && $cp <= 0xE01EF) ||
        $cp == 0x200C
    }
}

proc ::tclutils::tustr::_regional {cp} { expr {$cp >= 0x1F1E6 && $cp <= 0x1F1FF} }

# Split S into user-perceived characters. [llength [graphemes $s]] is the
# visible length that [string length] gets wrong for "e\u0301" or flags.
proc ::tclutils::tustr::graphemes {s} {
    set cps [_codepoints $s]
    set n [expr {[llength $cps] / 2}]
    set out {}
    set i 0
    while {$i < $n} {
        lassign [lrange $cps [expr {2*$i}] [expr {2*$i+1}]] cl cp
        incr i
        if {$cp == 0x0D && $i < $n && [lindex $cps [expr {2*$i+1}]] == 0x0A} {
            append cl [lindex $cps [expr {2*$i}]]
            incr i
            lappend out $cl
            continue
        }
        set ri [expr {[_regional $cp] ? 1 : 0}]
        while {$i < $n} {
            lassign [lrange $cps [expr {2*$i}] [expr {2*$i+1}]] c cp
            if {[_extend $cp]} { append cl $c; incr i; continue }
            if {$cp == 0x200D} {                 ;# ZWJ joins the next base
                append cl $c; incr i
                if {$i < $n} { append cl [lindex $cps [expr {2*$i}]]; incr i }
                continue
            }
            if {$ri == 1 && [_regional $cp]} {   ;# second half of a flag
                append cl $c; incr i; set ri 2; continue
            }
            break
        }
        lappend out $cl
    }
    return $out
}

# 1 if CHAR (one character, or a surrogate pair under 8.6) is printable,
# i.e. not a C0 control (< U+0020), DEL or C1 control (U+007F..U+009F).
# U+00A0 (no-break space) counts as printable. Empty string or more than one
# character: {TCLUTILS TUSTR ARG}.
proc ::tclutils::tustr::isPrintable {char} {
    set cps [_codepoints $char]
    if {[llength $cps] != 2} {
        return -code error -errorcode {TCLUTILS TUSTR ARG} \
            "isPrintable expects exactly one character"
    }
    set cp [lindex $cps 1]
    if {$cp < 0x20} { return 0 }
    if {$cp >= 0x7F && $cp <= 0x9F} { return 0 }
    return 1
}

package provide tclutils::tustr 0.2
