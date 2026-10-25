# tclutils::tuldif -- LDIF (RFC 2849) reader/writer
# Description: LDIF (RFC 2849) reader/writer
# Category: Data · structures & formats
#
# Parses LDIF text into a list of entries and serializes entries back to LDIF.
# An entry is an ordered list of {attribute value} pairs (the dn is just the
# first attribute, "dn"). Multi-valued attributes appear as repeated pairs.
# Base64 values (attr:: ...) are decoded via tclutils::tubase64 and re-encoded
# on output when a value is not LDIF-safe. RFC 2849 values are UTF-8: a base64
# value is decoded from UTF-8 after tubase64, and encoded to UTF-8 before it.
# A value is not safe when it starts with space, ':' or '<', ends with a
# space, or holds a character outside 32..126.
#
# Only content records are read. A change record (changetype: ...) raises
# {TCLUTILS TULDIF CHANGETYPE}.

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

# Decode the bytes of a base64 value as UTF-8. Bytes that are not valid UTF-8
# (a binary attribute such as jpegPhoto) come back unchanged, one character
# per byte -- Tcl 9.0 would raise on them, Tcl 8.6 would map them silently.
proc ::tclutils::tuldif::_fromUtf8 {bytes} {
    if {[catch {encoding convertfrom utf-8 $bytes} text]
            || [encoding convertto utf-8 $text] ne $bytes} {
        return $bytes
    }
    return $text
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
        set b64 [string trim [string range $rest 1 end]]
        set val [_fromUtf8 [::tclutils::tubase64::decode $b64]]
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
        if {[string equal -nocase [lindex $pair 0] changetype]} {
            return -code error -errorcode {TCLUTILS TULDIF CHANGETYPE} \
                "LDIF change records are not supported\
                 (changetype: [string trim [lindex $pair 1]])"
        }
        lappend cur $pair
    }
    if {[llength $cur]} { lappend entries $cur }
    return $entries
}

proc ::tclutils::tuldif::_needsBase64 {val} {
    if {$val eq ""} { return 0 }
    if {[string index $val 0] in {" " ":" "<"}} { return 1 }
    # RFC 2849 note 8: a trailing space would be lost by many readers.
    if {[string index $val end] eq " "} { return 1 }
    foreach ch [split $val ""] {
        scan $ch %c code
        if {$code < 32 || $code > 126} { return 1 }
    }
    return 0
}

proc ::tclutils::tuldif::_emitLine {attr val} {
    if {[_needsBase64 $val]} {
        set bytes [encoding convertto utf-8 $val]
        return "${attr}:: [::tclutils::tubase64::encode $bytes]"
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

package provide tclutils::tuldif 0.2
