# tustate-0.1.tm -- parse Mermaid stateDiagram / stateDiagram-v2 into a
# Description: parse Mermaid stateDiagram / stateDiagram-v2 into a tclutils::tudiagram model.
# Category: Diagrams · Mermaid
# tclutils::tudiagram model.
#
#   states        -> rounded boxes
#   transitions   -> edges (A --> B, optional ": label")
#   [*]           -> start (__start) / end (__end) dot marker, by side
#   "S : text"    -> sets state S's display label
#   state X <<fork>>|<<join>>  -> a labelled box named X (v1)
#   direction LR|RL|TB|TD|BT   -> layout direction (RL->LR, BT/TD->TB)
#
# v1 limitations (honest): composite states `state X { ... }` are FLATTENED
# (inner transitions are kept, the boundary box is not drawn); notes are
# ignored; fork/join are boxes, not bars; self-loops are not drawn (tudiagram).
#
# Namespace: ::tclutils::tustate   Package: tclutils::tustate 0.1
# Errors:    {TCLUTILS TUSTATE <REASON>}   REASON in EMPTY

package require Tcl 8.6 9
package require tclutils::common
package require tclutils::tudiagram

namespace eval ::tclutils::tustate {
    namespace export parse
}

proc ::tclutils::tustate::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUSTATE $reason] $msg
}

# Ensure a node id exists in the order/shape/label arrays. side "from"/"to"
# only matters for the [*] pseudostate (start vs end).
proc ::tclutils::tustate::_resolve {endpoint side oV lV sV} {
    upvar 1 $oV order $lV label $sV shape
    set ep [string trim $endpoint]
    set ep [string trim $ep \"]
    if {$ep eq {[*]}} {
        set id [expr {$side eq "from" ? "__start" : "__end"}]
        if {![info exists shape($id)]} { lappend order $id; set shape($id) dot; set label($id) "" }
        return $id
    }
    if {![info exists shape($ep)]} { lappend order $ep; set shape($ep) rounded; set label($ep) $ep }
    return $ep
}

proc ::tclutils::tustate::parse {text} {
    set dir TB
    set order {}            ;# node ids, first-seen order
    array set label {}      ;# id -> display label
    array set shape {}      ;# id -> rounded|dot
    set edges {}            ;# list of {from to label}
    set headerSeen 0
    set inNote 0

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue

        # header (may appear more than once in composite examples -> ignore extra)
        if {[regexp -nocase {^stateDiagram(-v2)?\M} $line]} { set headerSeen 1; continue }

        # block notes: skip until "end note"; single-line "note ... : text": skip
        if {[regexp {^note\M} $line]} {
            if {![string match "*:*" $line]} { set inNote 1 }
            continue
        }
        if {$inNote} { if {[regexp {^end note\M} $line]} { set inNote 0 }; continue }

        # composite state wrapper -> flatten (keep inner lines, drop the boundary)
        if {[regexp {^state\s+\S+\s*\{\s*$} $line]} continue
        if {$line eq "\}"} continue

        # fork/join declaration -> a named box (v1)
        if {[regexp {^state\s+(\S+)\s+<<(fork|join)>>} $line -> sid _k]} {
            if {![info exists shape($sid)]} { lappend order $sid; set shape($sid) rounded; set label($sid) $sid }
            continue
        }

        # direction
        if {[regexp -nocase {^direction\s+(LR|RL|TB|TD|BT)\M} $line -> dd]} {
            set dd [string toupper $dd]
            switch -- $dd { RL {set dir LR} BT {set dir TB} TD {set dir TB} default {set dir $dd} }
            continue
        }

        # transition:  A --> B   (optional  ": label")
        if {[regexp {^(.+?)\s*-->\s*([^:]+?)\s*(?::\s*(.*))?$} $line -> a b lbl]} {
            set fromId [_resolve $a from order label shape]
            set toId   [_resolve $b to   order label shape]
            lappend edges [list $fromId $toId [string trim $lbl]]
            continue
        }

        # state description:  S : free text  (no transition)
        if {[regexp {^([A-Za-z0-9_]+)\s*:\s*(.+)$} $line -> sid desc]} {
            if {![info exists shape($sid)]} { lappend order $sid; set shape($sid) rounded }
            set label($sid) [string trim $desc]
            continue
        }

        # bare state name on its own line
        if {[regexp {^[A-Za-z0-9_]+$} $line]} {
            if {![info exists shape($line)]} { lappend order $line; set shape($line) rounded; set label($line) $line }
            continue
        }
        # anything else: ignored (v1)
    }

    if {![llength $order]} { _err EMPTY "no states found in stateDiagram" }

    set d [::tclutils::tudiagram::create -direction $dir]
    foreach id $order {
        set d [::tclutils::tudiagram::addNode $d $id -label $label($id) -shape $shape($id)]
    }
    foreach e $edges {
        lassign $e f t l
        set d [::tclutils::tudiagram::addEdge $d $f $t -label $l -arrow end]
    }
    return $d
}

package provide tclutils::tustate 0.1
