# tuarchitecture-0.1.tm -- parse a Mermaid `architecture-beta` diagram into a
# tclutils::tudiagram model, so an architecture block renders natively (SVG or
# PNG) through the pure-Tcl engine everywhere -- no browser. Like `tuc4`, this
# is a graph parser: it only builds a tudiagram model and is reached through the
# `tclutils::tuflow` facade, which dispatches `architecture-beta` to parse here
# and then lays the graph out with tudiagram.
#
# Supported syntax (Mermaid subset):
#   architecture-beta                      -> header (also bare `architecture`)
#   group <id>(<icon>)[<Label>]            -> a group, drawn as a cluster frame
#   service <id>(<icon>)[<Label>] in <g>   -> a service node ( `in <group>`
#                                             optional)
#   junction <id>                          -> a routing point (drawn as a dot)
#   <id>:<S> -- <S>:<id>                    -> edge, no arrowhead
#   <id>:<S> --> <S>:<id>                   -> edge, arrowhead at the target
#                                             ( `<--` / `<-->` also recognised;
#                                             S is a side L|R|T|B)
#   %% ...                                  -> comment
#
# The display label is the `[Label]` (or the id if absent). The `(icon)` maps to
# a node shape so families stay readable without an external icon set:
#   database / disk            -> cylinder
#   cloud / internet           -> rounded
#   server / everything else   -> box
# Edge endpoints that were never declared are created as plain boxes (so an edge
# to a group id still renders), exactly like tuc4 does for relationship ends.
#
# v1 limitations (honest):
#   - GROUPS draw as cluster frames (tudiagram >= 0.4): a `group` becomes a
#     labelled box around the bounding box of its `in <group>` members, with
#     nested `group ... in <parent>` honoured. The frame is post-hoc over the
#     laid-out members, so for a group whose members the layout scatters the box
#     can be loose -- it is tight when a group is a connected sub-cluster. A
#     group referenced by an edge is still drawn as a plain node.
#   - The side hints (:L :R :T :B) are parsed but NOT used to route edges -- the
#     engine decides port positions (same as tuc4's Rel_U/D/L/R hints).
#   - Icons are mapped to shapes, not drawn as glyphs (no Iconify dependency).
#
# mermaid.js compatibility (IMPORTANT for ```mermaid``` fences in HTML export):
#   This parser accepts a LENIENT SUPERSET of mermaid.js `architecture-beta`.
#   Everything in the official mermaid examples renders identically here
#   (verified): `group id(icon)[Label] (in parent)?`, `service id(icon)[Label]
#   (in group)?`, edges `a:S -- S:b` / `-->` / `<--` / `<-->`, `junction id`,
#   the built-in icons cloud|database|disk|internet|server, and the cross-group
#   `id{group}` edge modifier (tolerated -- the modifier is stripped, the edge
#   still connects). BUT tuflow also tolerates things mermaid.js 11.x rejects
#   (e.g. very lenient ids/labels), so a fence that renders here may still throw
#   "Syntax error" in a browser that hands the SAME text to mermaid.js. For a
#   ```mermaid``` block that must render in BOTH the browser and natively, write
#   canonical mermaid.js (the official-example subset above). To render natively
#   only and bypass mermaid.js, use a ```flow``` fence (docir renders inline SVG
#   via tuflow). See docs/tuarchitecture.md for the safe-subset checklist.
#
# Namespace: ::tclutils::tuarchitecture   Package: tclutils::tuarchitecture 0.1
# Errors:    {TCLUTILS TUARCHITECTURE <REASON>}   REASON in EMPTY

package require Tcl 8.6 9
package require tclutils::common
package require tclutils::tudiagram

namespace eval ::tclutils::tuarchitecture {
    namespace export parse
}

proc ::tclutils::tuarchitecture::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUARCHITECTURE $reason] $msg
}

# Map a Mermaid architecture icon name to a tudiagram shape. Unknown / absent
# icons fall back to a plain box.
proc ::tclutils::tuarchitecture::_iconShape {icon} {
    switch -nocase -- [string trim $icon] {
        database - db - disk - storage { return cylinder }
        cloud - internet               { return rounded }
        default                        { return box }
    }
}

proc ::tclutils::tuarchitecture::parse {text} {
    set order {}            ;# node ids, first-seen order
    array set label {}      ;# id -> display label
    array set shape {}      ;# id -> shape
    set groups {}           ;# declared group ids, in order
    array set groupLabel {} ;# gid -> label
    array set groupParent {};# gid -> parent gid (nested groups) or ""
    array set groupOf {}    ;# service/junction id -> group id it sits in
    set edges {}            ;# list of {from to arrow}

    # Declare (or update) a node, keeping first-seen order.
    set ensure {{id lbl shp oV lV sV} {
        upvar 1 $oV order $lV label $sV shape
        if {[info exists shape($id)]} {
            if {$shp ne ""} { set shape($id) $shp }
            if {$lbl ne ""} { set label($id) $lbl }
        } else {
            lappend order $id
            set shape($id) [expr {$shp ne "" ? $shp : "box"}]
            set label($id) [expr {$lbl ne "" ? $lbl : $id}]
        }
    }}

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {[regexp -nocase {^architecture(-beta)?\M} $line]} continue

        # group <id>(<icon>)[<Label>] ?in <parent>?  -> drawn as a cluster frame
        if {[regexp -nocase {^group\s+([A-Za-z0-9_]+)\s*(?:\(([^)]*)\))?\s*(?:\[([^\]]*)\])?\s*(?:in\s+([A-Za-z0-9_]+))?\s*$} \
                $line -> gid gicon glbl gparent]} {
            if {$gid ni $groups} { lappend groups $gid }
            set groupLabel($gid) [expr {$glbl ne "" ? $glbl : $gid}]
            if {$gparent ne ""} { set groupParent($gid) $gparent }
            continue
        }

        # service <id>(<icon>)[<Label>] ?in <group>?
        if {[regexp -nocase {^service\s+([A-Za-z0-9_]+)\s*(?:\(([^)]*)\))?\s*(?:\[([^\]]*)\])?\s*(?:in\s+([A-Za-z0-9_]+))?\s*$} \
                $line -> sid icon lbl sgroup]} {
            apply $ensure $sid $lbl [_iconShape $icon] order label shape
            if {$sgroup ne ""} { set groupOf($sid) $sgroup }
            continue
        }

        # junction <id> ?in <group>?  -> a small routing dot
        if {[regexp -nocase {^junction\s+([A-Za-z0-9_]+)\s*(?:in\s+([A-Za-z0-9_]+))?\s*$} \
                $line -> jid jgroup]} {
            apply $ensure $jid $jid dot order label shape
            if {$jgroup ne ""} { set groupOf($jid) $jgroup }
            continue
        }

        # edge:  <id>(:S)? <conn> (S:)?<id>    conn in -- --> <-- <-->
        # tolerate mermaid's cross-group `{group}` modifier on either endpoint
        # (v1 does not do cross-group routing, but still connects the services).
        set eline $line
        regsub -all {\{[^\}]*\}} $eline "" eline
        if {[regexp {^([A-Za-z0-9_]+)(?::[LRTBlrtb])?\s*([<>]?--[>]?)\s*(?:[LRTBlrtb]:)?([A-Za-z0-9_]+)\s*$} \
                $eline -> from conn to]} {
            set hasEnd   [string match {*>} $conn]
            set hasStart [string match {<*} $conn]
            if {$hasStart && $hasEnd} {
                set arrow both
            } elseif {$hasEnd} {
                set arrow end
            } elseif {$hasStart} {
                set arrow start
            } else {
                set arrow none
            }
            apply $ensure $from "" "" order label shape
            apply $ensure $to   "" "" order label shape
            lappend edges [list $from $to $arrow]
            continue
        }
        # anything else (v1): ignored
    }

    if {![llength $order]} { _err EMPTY "no services found in architecture diagram" }

    set d [::tclutils::tudiagram::create -direction LR]
    foreach id $order {
        set d [::tclutils::tudiagram::addNode $d $id \
            -label $label($id) -shape $shape($id)]
    }
    foreach e $edges {
        lassign $e f t a
        set d [::tclutils::tudiagram::addEdge $d $f $t -arrow $a]
    }

    # groups -> cluster frames (tudiagram >= 0.4; no-op on 0.3 via info commands).
    # Collect direct members, roll nested child members up into their parents so
    # an outer group's member set is a superset of its inner group's.
    array set gm {}
    foreach g $groups { set gm($g) {} }
    foreach s [array names groupOf] {
        set g $groupOf($s)
        if {$g ni $groups} { lappend groups $g; set groupLabel($g) $g; set gm($g) {} }
        lappend gm($g) $s
    }
    for {set pass 0} {$pass < [llength $groups]} {incr pass} {
        foreach g $groups {
            if {![info exists groupParent($g)]} continue
            set p $groupParent($g)
            if {$p ni $groups} continue
            foreach m $gm($g) { if {$m ni $gm($p)} { lappend gm($p) $m } }
        }
    }
    if {[llength [info commands ::tclutils::tudiagram::addGroup]]} {
        foreach g $groups {
            if {[llength $gm($g)]} {
                set d [::tclutils::tudiagram::addGroup $d $g \
                    -label $groupLabel($g) -members [lsort -unique $gm($g)]]
            }
        }
    }
    return $d
}

package provide tclutils::tuarchitecture 0.1
