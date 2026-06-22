# tuclass-0.1.tm -- parse Mermaid classDiagram into a tclutils::tudiagram model.
#
#   class X { +int a; +m() }   /  X : +int a  /  X : +m()   -> box with
#       three compartments (name / attributes / methods), separated by a
#       dashed line (members with "()" are methods, the rest attributes).
#   A <|-- B   B inherits A    -> edge B->A labelled "extends"
#   A *-- B / A o-- B / A --> B / A ..> B  (and reversed forms) -> labelled edge
#   explicit "A <|-- B : label" -> that label wins.
#
# v1 limitations (honest): compartments are shown with a dashed separator line,
# not real drawn box dividers; UML arrowheads (hollow triangle, diamond) are not
# drawn -- the relationship kind is shown as an edge label instead, with ".."
# relationships (dependency / realization) drawn as a dashed line; cardinality
# strings ("1", "*") are ignored.
#
# Namespace: ::tclutils::tuclass   Package: tclutils::tuclass 0.1
# Errors:    {TCLUTILS TUCLASS <REASON>}   REASON in EMPTY

package require Tcl 8.6 9
package require tclutils::common
package require tclutils::tudiagram

namespace eval ::tclutils::tuclass {
    namespace export parse
}

proc ::tclutils::tuclass::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUCLASS $reason] $msg
}

# relationship kind from the operator (for the edge label)
proc ::tclutils::tuclass::_reltype {op} {
    if {[string match {*|*} $op]} { return "extends" }
    if {[string match {*\**} $op]} { return "composition" }
    if {[string match {*o*} $op]} { return "aggregation" }
    if {[string match {*.*} $op]} { return "dependency" }
    return ""
}

proc ::tclutils::tuclass::parse {text} {
    set order {}
    array set attrs {}      ;# class -> list of attribute lines
    array set methods {}    ;# class -> list of method lines
    set edges {}            ;# list of {from to label}
    set state ""
    set curClass ""

    set ensure {{name oV aV mV} {
        upvar 1 $oV order $aV attrs $mV methods
        if {$name ni $order} { lappend order $name; set attrs($name) {}; set methods($name) {} }
    }}
    set addMember {{name member aV mV} {
        upvar 1 $aV attrs $mV methods
        if {[string match {*(*} $member]} { lappend methods($name) $member } \
        else                               { lappend attrs($name)   $member }
    }}

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {[regexp -nocase {^classDiagram(-v2)?\M} $line]} continue

        if {$state eq "block"} {
            if {[string match "*\}*" $line]} { set state ""; continue }
            if {$line ne ""} { apply $addMember $curClass $line attrs methods }
            continue
        }

        # class block open (class name optionally touching an opening brace)
        if {[regexp {^class\s+(\w+)\s*\{} $line -> cls]} {
            set curClass $cls
            apply $ensure $cls order attrs methods
            set state block
            continue
        }
        # plain class declaration:  class X
        if {[regexp {^class\s+(\w+)\s*$} $line -> cls]} {
            apply $ensure $cls order attrs methods
            continue
        }

        # relationship:  A <op> B  [: label]
        if {[regexp {^(\w+)\s+([<>|*o.~+-]+)\s+(\w+)\s*(?::\s*(.*))?$} $line -> a op b lbl]} {
            apply $ensure $a order attrs methods
            apply $ensure $b order attrs methods
            set lbl [string trim $lbl]
            if {$lbl eq ""} { set lbl [_reltype $op] }
            # ".." operators (dependency / realization) are drawn dashed
            set est [expr {[string match {*.*} $op] ? "dashed" : "solid"}]
            # arrowhead on the left ("<...") -> child is on the right
            if {[string index $op 0] eq "<"} {
                lappend edges [list $b $a $lbl $est]
            } else {
                lappend edges [list $a $b $lbl $est]
            }
            continue
        }

        # shorthand member:  X : +int age   /   X : +m()
        if {[regexp {^(\w+)\s*:\s*(.+)$} $line -> cls member]} {
            apply $ensure $cls order attrs methods
            apply $addMember $cls [string trim $member] attrs methods
            continue
        }
    }

    if {![llength $order]} { _err EMPTY "no classes found in classDiagram" }

    set d [::tclutils::tudiagram::create -direction TB]
    foreach id $order {
        set parts [list $id]
        if {[llength $attrs($id)]} {
            lappend parts "----------"
            foreach a $attrs($id) { lappend parts $a }
        }
        if {[llength $methods($id)]} {
            lappend parts "----------"
            foreach m $methods($id) { lappend parts $m }
        }
        set d [::tclutils::tudiagram::addNode $d $id -label [join $parts \n] -shape box]
    }
    foreach e $edges {
        lassign $e a b l est
        set d [::tclutils::tudiagram::addEdge $d $a $b -label $l -style $est -arrow end]
    }
    return $d
}

package provide tclutils::tuclass 0.1
