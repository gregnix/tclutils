# tclutils::tuldif -- LDIF (RFC 2849) reader/writer
#
# Parses LDIF text into a list of entries and serializes entries back to LDIF.
# An entry is an ordered list of {attribute value} pairs (the dn is just the
# first attribute, "dn"). Multi-valued attributes appear as repeated pairs.
# Base64 values (attr:: ...) are decoded via tclutils::tubase64 and re-encoded
# on output when a value is not LDIF-safe.

package require Tcl 8.6-
package require tclutils::tubase64 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuldif {
    namespace export parse toLdif dn get attributes toDict \
        addAttr removeAttr setAttr
}

# Unfold continuation lines (a line beginning with a single space continues the
# previous one) and normalize line endings. Returns a list of logical lines.
proc ::tclutils::tuldif::_unfold {ldif} {
    set out {}
    set norm [string map [list "\r\n" "\n" "\r" "\n"] $ldif]
    foreach raw [split $norm "\n"] {
        if {[string length $raw] && [string index $raw 0] eq " "} {
            if {[llength $out]} {
                lset out end [lindex $out end][string range $raw 1 end]
            }
        } else {
            lappend out $raw
        }
    }
    return $out
}

proc ::tclutils::tuldif::_parseLine {line} {
    set ci [string first ":" $line]
    if {$ci < 0} {
        return -code error -errorcode {TCLUTILS TULDIF SYNTAX} \
            "LDIF line without ':' -> $line"
    }
    set attr [string range $line 0 [expr {$ci - 1}]]
    set rest [string range $line [expr {$ci + 1}] end]
    set t [string index $rest 0]
    if {$t eq ":"} {
        set val [::tclutils::tubase64::decode [string trim [string range $rest 1 end]]]
    } elseif {$t eq "<"} {
        set val [string trim [string range $rest 1 end]]
    } elseif {$t eq " "} {
        set val [string range $rest 1 end]
    } else {
        set val $rest
    }
    return [list $attr $val]
}

# Parse LDIF text into a list of entries (each an ordered list of {attr value}).
proc ::tclutils::tuldif::parse {ldif} {
    set entries {}
    set cur {}
    foreach line [_unfold $ldif] {
        if {$line eq ""} {
            if {[llength $cur]} { lappend entries $cur; set cur {} }
            continue
        }
        if {[string index $line 0] eq "#"} continue
        set pair [_parseLine $line]
        if {[lindex $pair 0] eq "version"} continue
        lappend cur $pair
    }
    if {[llength $cur]} { lappend entries $cur }
    return $entries
}

proc ::tclutils::tuldif::_needsBase64 {val} {
    if {$val eq ""} { return 0 }
    if {[string index $val 0] in {" " ":" "<"}} { return 1 }
    foreach ch [split $val ""] {
        scan $ch %c code
        if {$code < 32 || $code > 126} { return 1 }
    }
    return 0
}

proc ::tclutils::tuldif::_emitLine {attr val} {
    if {[_needsBase64 $val]} {
        return "${attr}:: [::tclutils::tubase64::encode $val]"
    }
    return "${attr}: $val"
}

# Serialize a list of entries back to LDIF text.
proc ::tclutils::tuldif::toLdif {entries} {
    set out {}
    foreach entry $entries {
        foreach pair $entry {
            lappend out [_emitLine [lindex $pair 0] [lindex $pair 1]]
        }
        lappend out ""
    }
    return [join $out "\n"]
}

# --- accessors ---

# The dn of an entry ("" if none).
proc ::tclutils::tuldif::dn {entry} {
    foreach pair $entry {
        if {[string equal -nocase [lindex $pair 0] dn]} { return [lindex $pair 1] }
    }
    return ""
}

# All values of an attribute (case-insensitive), in order.
proc ::tclutils::tuldif::get {entry attr} {
    set out {}
    foreach pair $entry {
        if {[string equal -nocase [lindex $pair 0] $attr]} {
            lappend out [lindex $pair 1]
        }
    }
    return $out
}

# Attribute names in first-seen order (unique).
proc ::tclutils::tuldif::attributes {entry} {
    set out {}
    foreach pair $entry {
        set a [lindex $pair 0]
        if {$a ni $out} { lappend out $a }
    }
    return $out
}

# Entry as a dict attr -> list of values (first-seen key order).
proc ::tclutils::tuldif::toDict {entry} {
    set d [dict create]
    foreach pair $entry {
        dict lappend d [lindex $pair 0] [lindex $pair 1]
    }
    return $d
}

# Return a copy of an entry with an {attr value} pair appended.
proc ::tclutils::tuldif::addAttr {entry attr value} {
    lappend entry [list $attr $value]
    return $entry
}

# Return a copy of an entry with the pair at index removed.
proc ::tclutils::tuldif::removeAttr {entry index} {
    return [lreplace $entry $index $index]
}

# Return a copy of an entry with the pair at index replaced.
proc ::tclutils::tuldif::setAttr {entry index attr value} {
    return [lreplace $entry $index $index [list $attr $value]]
}

package provide tclutils::tuldif 0.1
