# tuc4-0.1.tm -- parse a Mermaid C4 diagram into a tclutils::tudiagram model.
# Description: parse a Mermaid C4 diagram into a tclutils::tudiagram model.
# Category: Diagrams · Mermaid
#
# Handles C4Context / C4Container / C4Component / C4Dynamic / C4Deployment.
#
#   Person(id,"name",...) / Person_Ext(...)      -> rounded box (actor)
#   System(...) Container(...) Component(...)     -> box
#   SystemDb(...) ContainerDb(...) ...           -> cylinder (database)
#   *_Ext variants                               -> grey (external)
#   Rel(from,to,"label",...) / BiRel / Rel_U|D|L|R -> edge from->to, label
#   title <text>                                  -> diagram title
#   *_Boundary(...) { ... } / Deployment_Node {…} -> flattened (see below)
#   UpdateElementStyle / UpdateRelStyle / Update… -> ignored
#
# An element's display label is its "name" (the first quoted argument). A
# leading id token is used as the node id. Elements are filled by type colour
# (Person, System, Container, Component, External) so families stay readable.
#
# v1 limitations (honest): boundaries (Enterprise/System/Container_Boundary,
# Boundary, Deployment_Node, Node) are FLATTENED -- their inner elements are
# kept, the boundary box itself is not drawn; the technology/description
# arguments are not shown (only the name); BiRel renders as a single-headed
# edge; the directional Rel_U/D/L/R hints are ignored (tudiagram lays the
# graph out top-down).
#
# Namespace: ::tclutils::tuc4   Package: tclutils::tuc4 0.1
# Errors:    {TCLUTILS TUC4 <REASON>}   REASON in EMPTY

package require Tcl 8.6 9
package require tclutils::common
package require tclutils::tudiagram

namespace eval ::tclutils::tuc4 {
    namespace export parse
}

proc ::tclutils::tuc4::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUC4 $reason] $msg
}

# Colour a node by its C4 element type. Light fills keep the dark label legible.
# Any *_Ext element is grey (external); otherwise the base type decides.
proc ::tclutils::tuc4::_typeStyle {type} {
    if {[regexp -nocase {_Ext$}    $type]} { return {fill #eeeeee stroke #757575} }
    if {[regexp -nocase {^Person}    $type]} { return {fill #e8def8 stroke #6a1b9a} }
    if {[regexp -nocase {^Container} $type]} { return {fill #e3f2e8 stroke #2e7d32} }
    if {[regexp -nocase {^Component} $type]} { return {fill #fff3df stroke #e65100} }
    if {[regexp -nocase {^System}    $type]} { return {fill #d6e8fb stroke #0b5394} }
    return {}
}

proc ::tclutils::tuc4::parse {text} {
    set title ""
    set order {}            ;# node ids, first-seen order
    array set label {}      ;# id -> display label
    array set shape {}      ;# id -> box|rounded|cylinder
    array set style {}      ;# id -> -style dict (by element type)
    set edges {}            ;# list of {from to label}

    set ensure {{id lbl shp oV lV sV} {
        upvar 1 $oV order $lV label $sV shape
        if {![info exists shape($id)]} {
            lappend order $id
            set shape($id) $shp
            set label($id) $lbl
        }
    }}

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {[regexp -nocase {^C4(Context|Container|Component|Dynamic|Deployment)\M} $line]} continue
        if {[regexp {^Update} $line]} continue
        if {$line eq "\}"} continue            ;# boundary close -> flatten
        if {[regexp {^title\s+(.+)$} $line -> t]} { set title [string trim $t]; continue }

        # Type( args ) optionally followed by an opening brace (boundary).
        if {![regexp {^([A-Za-z0-9_]+)\s*\((.*)\)\s*(\{)?\s*$} $line -> type args brace]} {
            continue   ;# anything else (v1): ignored
        }
        if {$brace ne ""} continue             ;# boundary open -> flatten

        if {[regexp {^(Rel|BiRel|Rel_)} $type]} {
            # relationship: from, to, then the first quoted label
            if {![regexp {^\s*([A-Za-z0-9_]+)\s*,\s*([A-Za-z0-9_]+)} $args -> from to]} continue
            set lbl ""
            if {[regexp {"([^"]*)"} $args -> l]} { set lbl $l }
            apply $ensure $from $from box order label shape
            apply $ensure $to   $to   box order label shape
            lappend edges [list $from $to $lbl]
        } else {
            # element: id, then the first quoted name
            if {![regexp {^\s*([A-Za-z0-9_]+)} $args -> id]} continue
            set name $id
            if {[regexp {"([^"]*)"} $args -> nm]} { set name $nm }
            set shp box
            if {[regexp -nocase {^Person} $type]} {
                set shp rounded
            } elseif {[regexp -nocase {Db} $type]} {
                set shp cylinder
            }
            set style($id) [_typeStyle $type]
            if {[info exists shape($id)]} {
                set shape($id) $shp
                set label($id) $name
            } else {
                lappend order $id; set shape($id) $shp; set label($id) $name
            }
        }
    }

    if {![llength $order]} { _err EMPTY "no elements found in C4 diagram" }

    set d [::tclutils::tudiagram::create -direction TB -title $title]
    foreach id $order {
        set d [::tclutils::tudiagram::addNode $d $id -label $label($id) -shape $shape($id) \
            -style [expr {[info exists style($id)] ? $style($id) : {}}]]
    }
    foreach e $edges {
        lassign $e f t l
        set d [::tclutils::tudiagram::addEdge $d $f $t -label $l -arrow end]
    }
    return $d
}

package provide tclutils::tuc4 0.1
