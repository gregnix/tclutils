# turequirement-0.1.tm -- parse Mermaid requirementDiagram into a
# Description: parse Mermaid requirementDiagram into a tclutils::tudiagram model.
# Category: Diagrams · Mermaid
# tclutils::tudiagram model.
#
#   requirement <name> { id: .. text: .. risk: .. verifymethod: .. }  -> box
#   element <name> { type: .. docref: .. }                            -> box
#   <src> - <relation> -> <dst>     (satisfies/derives/traces/...)    -> edge
#   <dst> <- <relation> - <src>                                       -> edge
#
# Requirement/element boxes carry a "<<type>>" stereotype line, the name, and
# the collected fields (ASCII only -- the bitmap font has no guillemets).
#
# v1 limitations (honest): long field values (e.g. text:) make wide boxes
# (no wrapping); requirement sub-types all render as plain boxes.
#
# Namespace: ::tclutils::turequirement   Package: tclutils::turequirement 0.1
# Errors:    {TCLUTILS TUREQUIREMENT <REASON>}   REASON in EMPTY

package require Tcl 8.6 9
package require tclutils::common
package require tclutils::tudiagram

namespace eval ::tclutils::turequirement {
    namespace export parse
}

proc ::tclutils::turequirement::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUREQUIREMENT $reason] $msg
}

proc ::tclutils::turequirement::parse {text} {
    set order {}            ;# node names, first-seen order
    array set label {}      ;# name -> multi-line label
    set edges {}            ;# list of {src dst relation}
    set state ""            ;# "" | block
    set curKind ""
    set curName ""
    array set fields {}

    # ensure a node exists (default: a box labelled with its name)
    set ensure {{name oV lV} {
        upvar 1 $oV order $lV label
        if {![info exists label($name)]} { lappend order $name; set label($name) $name }
    }}

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {[regexp -nocase {^requirementDiagram\M} $line]} continue

        if {$state eq "block"} {
            if {[string match "*\}*" $line]} {
                # close block -> build the box label
                set lines [list "<<$curKind>>" $curName]
                foreach k {id text type risk verifymethod docref} {
                    if {[info exists fields($k)]} { lappend lines "$k: $fields($k)" }
                }
                if {$curName ni $order} { lappend order $curName }
                set label($curName) [join $lines \n]
                set state ""
                array unset fields
                continue
            }
            if {[regexp {^([A-Za-z_]+)\s*:\s*(.*)$} $line -> k v]} {
                set fields([string tolower $k]) [string trim $v]
            }
            continue
        }

        # open a requirement/element block
        if {[regexp -nocase {^(requirement|functionalRequirement|performanceRequirement|interfaceRequirement|physicalRequirement|designConstraint|element)\s+(\S+)\s*\{} \
                $line -> kind name]} {
            set curKind $kind
            set curName $name
            array unset fields
            set state block
            continue
        }

        # relationship: src - relation -> dst
        if {[regexp {^(\S+)\s*-\s*(\w+)\s*->\s*(\S+)$} $line -> src rel dst]} {
            apply $ensure $src order label
            apply $ensure $dst order label
            lappend edges [list $src $dst $rel]
            continue
        }
        # reverse: dst <- relation - src
        if {[regexp {^(\S+)\s*<-\s*(\w+)\s*-\s*(\S+)$} $line -> dst rel src]} {
            apply $ensure $src order label
            apply $ensure $dst order label
            lappend edges [list $src $dst $rel]
            continue
        }
        # anything else ignored (v1)
    }

    if {![llength $order]} { _err EMPTY "no requirements/elements found" }

    set d [::tclutils::tudiagram::create -direction TB]
    foreach id $order {
        set d [::tclutils::tudiagram::addNode $d $id -label $label($id) -shape box]
    }
    foreach e $edges {
        lassign $e src dst rel
        set d [::tclutils::tudiagram::addEdge $d $src $dst -label $rel -arrow end]
    }
    return $d
}

package provide tclutils::turequirement 0.1
