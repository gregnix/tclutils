# tclutils::tuical -- iCalendar (RFC 5545) reader/writer
#
# Parses iCalendar text into a tree of components and serializes it back with
# proper line folding. A component is a dict:
#   {type TYPE props {propDict ...} components {component ...}}
# A property is a dict: {name NAME value VALUE params {key value ...}}.
# parse returns the list of top-level components (usually one VCALENDAR).
#
# Property TEXT values are kept raw (as in the file) for exact round-tripping;
# use escapeText / unescapeText for the RFC 5545 TEXT escaping when needed.

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tuical {
    namespace export parse toIcs components properties property find events \
        setProperty addProperty removeProperty \
        escapeText unescapeText
}

# Unfold folded lines (continuation starts with space or tab).
proc ::tclutils::tuical::_unfold {ics} {
    set out {}
    set norm [string map [list "\r\n" "\n" "\r" "\n"] $ics]
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

proc ::tclutils::tuical::_parseProp {line} {
    set ci [string first ":" $line]
    if {$ci < 0} {
        return -code error -errorcode {TCLUTILS TUICAL SYNTAX} \
            "iCalendar line without ':' -> $line"
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

# Parse iCalendar text. Returns a list of top-level components.
proc ::tclutils::tuical::parse {ics} {
    set stack {}
    set top {}
    foreach line [_unfold $ics] {
        if {$line eq ""} continue
        lassign [_parseProp $line] name value params
        if {$name eq "BEGIN"} {
            lappend stack [dict create type $value props {} components {}]
        } elseif {$name eq "END"} {
            if {![llength $stack]} {
                return -code error -errorcode {TCLUTILS TUICAL SYNTAX} \
                    "END:$value without matching BEGIN"
            }
            set comp [lindex $stack end]
            set stack [lrange $stack 0 end-1]
            if {[llength $stack]} {
                set parent [lindex $stack end]
                dict lappend parent components $comp
                lset stack end $parent
            } else {
                lappend top $comp
            }
        } else {
            if {[llength $stack]} {
                set comp [lindex $stack end]
                set props [dict get $comp props]
                lappend props [dict create name $name value $value params $params]
                dict set comp props $props
                lset stack end $comp
            }
        }
    }
    if {[llength $stack]} {
        return -code error -errorcode {TCLUTILS TUICAL SYNTAX} \
            "unterminated component: [dict get [lindex $stack end] type]"
    }
    return $top
}

proc ::tclutils::tuical::_isComponent {x} {
    expr {[catch {dict get $x type}] == 0 && [catch {dict get $x props}] == 0}
}

# Fold a single content line to <=75 chars using CRLF + space continuations.
proc ::tclutils::tuical::_fold {line} {
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

proc ::tclutils::tuical::_emitComp {comp outVar} {
    upvar 1 $outVar out
    lappend out [_fold "BEGIN:[dict get $comp type]"]
    foreach p [dict get $comp props] {
        set line [dict get $p name]
        foreach {k v} [dict get $p params] {
            append line ";" $k
            if {$v ne ""} { append line "=" $v }
        }
        append line ":" [dict get $p value]
        lappend out [_fold $line]
    }
    foreach sub [dict get $comp components] { _emitComp $sub out }
    lappend out [_fold "END:[dict get $comp type]"]
}

# Serialize a component or a list of components to iCalendar text (CRLF).
proc ::tclutils::tuical::toIcs {comps} {
    if {[_isComponent $comps]} { set comps [list $comps] }
    set out {}
    foreach c $comps { _emitComp $c out }
    return [join $out "\r\n"]
}

# --- accessors ---

# Direct sub-components, optionally filtered by type.
proc ::tclutils::tuical::components {comp {type ""}} {
    set subs [dict get $comp components]
    if {$type eq ""} { return $subs }
    set out {}
    foreach c $subs {
        if {[string equal -nocase [dict get $c type] $type]} { lappend out $c }
    }
    return $out
}

# Property dicts, optionally filtered by name.
proc ::tclutils::tuical::properties {comp {name ""}} {
    set props [dict get $comp props]
    if {$name eq ""} { return $props }
    set out {}
    foreach p $props {
        if {[string equal -nocase [dict get $p name] $name]} { lappend out $p }
    }
    return $out
}

# First value of a named property ("" if absent).
proc ::tclutils::tuical::property {comp name} {
    foreach p [dict get $comp props] {
        if {[string equal -nocase [dict get $p name] $name]} {
            return [dict get $p value]
        }
    }
    return ""
}

# Recursively collect all components of a type from a component or list.
proc ::tclutils::tuical::find {comps type} {
    if {[_isComponent $comps]} { set comps [list $comps] }
    set out {}
    foreach c $comps {
        if {[string equal -nocase [dict get $c type] $type]} { lappend out $c }
        lappend out {*}[find [dict get $c components] $type]
    }
    return $out
}

# All VEVENT components (recursively).
proc ::tclutils::tuical::events {comps} {
    return [find $comps VEVENT]
}

# RFC 5545 TEXT escaping helpers.
proc ::tclutils::tuical::escapeText {s} {
    return [string map [list "\\" "\\\\" ";" "\\;" "," "\\," "\n" "\\n"] $s]
}
proc ::tclutils::tuical::unescapeText {s} {
    return [string map [list "\\n" "\n" "\\N" "\n" "\\," "," "\\;" ";" "\\\\" "\\"] $s]
}

# Return a copy of a component with the first property named NAME replaced
# (or a new property appended if none exists).
proc ::tclutils::tuical::setProperty {comp name value {params {}}} {
    set out {}
    set done 0
    foreach p [dict get $comp props] {
        if {!$done && [string equal -nocase [dict get $p name] $name]} {
            lappend out [dict create name $name value $value params $params]
            set done 1
        } else {
            lappend out $p
        }
    }
    if {!$done} {
        lappend out [dict create name $name value $value params $params]
    }
    dict set comp props $out
    return $comp
}

# Return a copy of a component with a property appended.
proc ::tclutils::tuical::addProperty {comp name value {params {}}} {
    set props [dict get $comp props]
    lappend props [dict create name $name value $value params $params]
    dict set comp props $props
    return $comp
}

# Return a copy of a component with all properties named NAME removed.
proc ::tclutils::tuical::removeProperty {comp name} {
    set out {}
    foreach p [dict get $comp props] {
        if {![string equal -nocase [dict get $p name] $name]} { lappend out $p }
    }
    dict set comp props $out
    return $comp
}

package provide tclutils::tuical 0.1
