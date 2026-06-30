# tuer-0.1.tm -- parse Mermaid erDiagram into a tclutils::tudiagram model.
# Description: parse Mermaid erDiagram into a tclutils::tudiagram model.
# Category: Diagrams · Mermaid
#
#   ENTITY { type name [key] ... }   -> a box: entity name + attribute lines
#   A <cardinality> B : label        -> an arrowless edge A--B labelled <label>,
#                                       with crow's-foot end-marks taken from the
#                                       cardinality; a ".." (non-identifying)
#                                       relationship is drawn dashed, "--"
#                                       (identifying) solid
#
# Cardinality markers (||, |o, }o, }| and their mirrored right-hand forms) are
# drawn as crow's-foot end-marks via tudiagram's -startMark/-endMark. v1
# limitations (honest): long attribute lists make tall boxes (no scrolling);
# keys (PK/FK) are appended in parentheses.
#
# Namespace: ::tclutils::tuer   Package: tclutils::tuer 0.1
# Errors:    {TCLUTILS TUER <REASON>}   REASON in EMPTY

package require Tcl 8.6 9
package require tclutils::common
package require tclutils::tudiagram 0.3

namespace eval ::tclutils::tuer {
    namespace export parse
}

proc ::tclutils::tuer::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUER $reason] $msg
}

# Map one side of an ER cardinality marker to a tudiagram end-mark value.
# Side-independent: "{"/"}" mean "many", "o" means "zero (optional)".
proc ::tclutils::tuer::_cardMark {marker} {
    set many [expr {[string match "*\{*" $marker] || [string match "*\}*" $marker]}]
    set zero [string match "*o*" $marker]
    if {$many} { return [expr {$zero ? "zeroOrMany" : "oneOrMany"}] }
    return [expr {$zero ? "zeroOrOne" : "exactlyOne"}]
}

proc ::tclutils::tuer::parse {text} {
    set order {}            ;# entity ids, first-seen order
    array set label {}      ;# id -> multi-line label (name + attrs)
    set edges {}            ;# list of {a b label}
    set state ""            ;# "" | block
    set curEntity ""
    set attrs {}

    set ensure {{name oV lV} {
        upvar 1 $oV order $lV label
        if {![info exists label($name)]} { lappend order $name; set label($name) $name }
    }}

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {[regexp -nocase {^erDiagram\M} $line]} continue

        if {$state eq "block"} {
            if {[string match "*\}*" $line]} {
                apply $ensure $curEntity order label
                set label($curEntity) [join [linsert $attrs 0 $curEntity] \n]
                set state ""
                set attrs {}
                continue
            }
            set toks [regexp -all -inline {\S+} $line]
            switch -- [llength $toks] {
                0 {}
                1 { lappend attrs [lindex $toks 0] }
                2 { lappend attrs "[lindex $toks 0] [lindex $toks 1]" }
                default {
                    lappend attrs "[lindex $toks 0] [lindex $toks 1] ([lindex $toks 2])"
                }
            }
            continue
        }

        # entity block open (entity name followed by an opening brace)
        if {[regexp {^([A-Za-z0-9_-]+)\s*\{\s*$} $line -> ent]} {
            set curEntity $ent
            set attrs {}
            set state block
            continue
        }

        # relationship:  A <cardinality> B  [: label]
        if {[regexp {^(\S+)\s+(\S+)\s+(\S+)\s*(?::\s*(.*))?$} $line -> a card b lbl]} {
            # ".." is a non-identifying relationship (dashed); "--" identifying
            set est [expr {[string match {*..*} $card] ? "dashed" : "solid"}]
            # split the cardinality around the separator into left/right markers
            if {[regexp {^(.*?)(\.\.|--)(.*)$} $card -> lm _sep rm]} {
                set sm [_cardMark $lm]
                set em [_cardMark $rm]
            } else {
                set sm none; set em none
            }
            apply $ensure $a order label
            apply $ensure $b order label
            lappend edges [list $a $b [string trim $lbl] $est $sm $em]
            continue
        }
        # bare entity name
        if {[regexp {^[A-Za-z0-9_-]+$} $line]} { apply $ensure $line order label; continue }
    }

    if {![llength $order]} { _err EMPTY "no entities found in erDiagram" }

    set d [::tclutils::tudiagram::create -direction TB]
    foreach id $order {
        set d [::tclutils::tudiagram::addNode $d $id -label $label($id) -shape box]
    }
    foreach e $edges {
        lassign $e a b l est sm em
        set d [::tclutils::tudiagram::addEdge $d $a $b -label $l -style $est \
            -arrow none -startMark $sm -endMark $em]
    }
    return $d
}

package provide tclutils::tuer 0.2
