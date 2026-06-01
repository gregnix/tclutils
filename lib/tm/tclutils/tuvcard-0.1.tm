# tclutils::tuvcard -- vCard (RFC 6350 / 2426) reader/writer
#
# Parses vCard text into a list of cards and serializes back with line folding.
# A card is a list of property dicts: {name NAME value VALUE params {k v ...}}.
# Property values are kept raw for exact round-tripping.

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tuvcard {
    namespace export parse toVcf property properties get names fullName \
        addProperty removeProperty setProperty
}

proc ::tclutils::tuvcard::_unfold {vcf} {
    set out {}
    set norm [string map [list "\r\n" "\n" "\r" "\n"] $vcf]
    foreach raw [split $norm "\n"] {
        set c [string index $raw 0]
        if {[llength $out] && ($c eq " " || $c eq "\t")} {
            lset out end [lindex $out end][string range $raw 1 end]
        } else {
            lappend out $raw
        }
    }
    return $out
}

proc ::tclutils::tuvcard::_parseProp {line} {
    set ci [string first ":" $line]
    if {$ci < 0} {
        return -code error -errorcode {TCLUTILS TUVCARD SYNTAX} \
            "vCard line without ':' -> $line"
    }
    set namepart [string range $line 0 [expr {$ci - 1}]]
    set value [string range $line [expr {$ci + 1}] end]
    set parts [split $namepart ";"]
    set name [lindex $parts 0]
    set params {}
    foreach p [lrange $parts 1 end] {
        set eq [string first "=" $p]
        if {$eq >= 0} {
            lappend params [string range $p 0 [expr {$eq - 1}]] \
                [string range $p [expr {$eq + 1}] end]
        } else {
            lappend params $p ""
        }
    }
    return [list $name $value $params]
}

# Parse vCard text -> list of cards (each a list of property dicts).
proc ::tclutils::tuvcard::parse {vcf} {
    set cards {}
    set cur {}
    set in 0
    foreach line [_unfold $vcf] {
        if {$line eq ""} continue
        lassign [_parseProp $line] name value params
        if {$name eq "BEGIN" && [string equal -nocase $value VCARD]} {
            set cur {}
            set in 1
            continue
        }
        if {$name eq "END" && [string equal -nocase $value VCARD]} {
            lappend cards $cur
            set in 0
            continue
        }
        if {$in} {
            lappend cur [dict create name $name value $value params $params]
        }
    }
    return $cards
}

proc ::tclutils::tuvcard::_fold {line} {
    if {[string length $line] <= 75} { return $line }
    set res [string range $line 0 74]
    set i 75
    set n [string length $line]
    while {$i < $n} {
        append res "\r\n " [string range $line $i [expr {$i + 73}]]
        incr i 74
    }
    return $res
}

proc ::tclutils::tuvcard::_emitCard {card outVar} {
    upvar 1 $outVar out
    lappend out [_fold "BEGIN:VCARD"]
    foreach p $card {
        set line [dict get $p name]
        foreach {k v} [dict get $p params] {
            append line ";" $k
            if {$v ne ""} { append line "=" $v }
        }
        append line ":" [dict get $p value]
        lappend out [_fold $line]
    }
    lappend out [_fold "END:VCARD"]
}

# Serialize a single card or a list of cards to vCard text (CRLF, folded).
proc ::tclutils::tuvcard::toVcf {cards} {
    # a single card is a list of property dicts; detect a list of cards by
    # checking whether the first element looks like a property dict.
    if {[llength $cards] && [catch {dict get [lindex $cards 0] name}] == 0} {
        set cards [list $cards]
    }
    set out {}
    foreach c $cards { _emitCard $c out }
    return [join $out "\r\n"]
}

# --- accessors (operate on a single card) ---

proc ::tclutils::tuvcard::properties {card {name ""}} {
    if {$name eq ""} { return $card }
    set out {}
    foreach p $card {
        if {[string equal -nocase [dict get $p name] $name]} { lappend out $p }
    }
    return $out
}

proc ::tclutils::tuvcard::property {card name} {
    foreach p $card {
        if {[string equal -nocase [dict get $p name] $name]} {
            return [dict get $p value]
        }
    }
    return ""
}

proc ::tclutils::tuvcard::get {card name} {
    set out {}
    foreach p $card {
        if {[string equal -nocase [dict get $p name] $name]} {
            lappend out [dict get $p value]
        }
    }
    return $out
}

proc ::tclutils::tuvcard::names {card} {
    set out {}
    foreach p $card { lappend out [dict get $p name] }
    return $out
}

# The formatted name (FN property).
proc ::tclutils::tuvcard::fullName {card} {
    return [property $card FN]
}

# Return a copy of a card with a property appended.
proc ::tclutils::tuvcard::addProperty {card name value {params {}}} {
    lappend card [dict create name $name value $value params $params]
    return $card
}

# Return a copy of a card with the property at index removed.
proc ::tclutils::tuvcard::removeProperty {card index} {
    return [lreplace $card $index $index]
}

# Return a copy of a card with the property at index replaced.
proc ::tclutils::tuvcard::setProperty {card index name value {params {}}} {
    return [lreplace $card $index $index \
        [dict create name $name value $value params $params]]
}

package provide tclutils::tuvcard 0.1
