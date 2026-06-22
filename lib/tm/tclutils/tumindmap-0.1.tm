# tumindmap-0.1.tm -- parse a Mermaid mindmap into a tclutils::tudiagram model.
#
#   mindmap                 -> header (ignored)
#   leading whitespace      -> hierarchy. Indentation is relative: a line
#                              indented deeper than the previous becomes its
#                              child; a shallower line returns to the nearest
#                              ancestor at a smaller indent. Tabs count as 4.
#   node text / shapes:
#       id((text))  ((text))         -> circle
#       id{{text}}  {{text}}         -> hexagon
#       id[text]    [text]    square -> box
#       id(text)    (text)            -> rounded
#       )text(   ))text((  (cloud/bang) -> rounded (no native shape)
#       plain text                      -> rounded
#   edges: parent -> child, drawn without an arrowhead (mindmap connectors).
#
# v1 limitations (honest): the result is laid out as a top-down layered tree
# (tudiagram), not the radial mermaid layout; node ids are generated, so an
# explicit mindmap id is used only as a label source and never as the id;
# `::icon(...)` and `class` decorator lines are ignored; markdown inside a
# label is kept verbatim.
#
# Namespace: ::tclutils::tumindmap   Package: tclutils::tumindmap 0.1
# Errors:    {TCLUTILS TUMINDMAP <REASON>}   REASON in EMPTY

package require Tcl 8.6 9
package require tclutils::common
package require tclutils::tudiagram

namespace eval ::tclutils::tumindmap {
    namespace export parse
}

proc ::tclutils::tumindmap::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUMINDMAP $reason] $msg
}

# Decode a node body into {label shape}. Shape delimiters are recognised only
# when they wrap the WHOLE body (so "API (REST)" stays plain text). An optional
# leading id token before the delimiter is dropped (the bracket text is used).
proc ::tclutils::tumindmap::_decode {body} {
    set t ""
    if {[regexp {^(?:[A-Za-z0-9_]+)?\)\)(.*)\(\($}   $body -> t]} { return [list [string trim $t] rounded] }
    if {[regexp {^(?:[A-Za-z0-9_]+)?\)(.*)\($}       $body -> t]} { return [list [string trim $t] rounded] }
    if {[regexp {^(?:[A-Za-z0-9_]+)?\(\((.*)\)\)$}   $body -> t]} { return [list [string trim $t] circle] }
    if {[regexp {^(?:[A-Za-z0-9_]+)?\{\{(.*)\}\}$}   $body -> t]} { return [list [string trim $t] hexagon] }
    if {[regexp {^(?:[A-Za-z0-9_]+)?\[(.*)\]$}       $body -> t]} { return [list [string trim $t] box] }
    if {[regexp {^(?:[A-Za-z0-9_]+)?\((.*)\)$}       $body -> t]} { return [list [string trim $t] rounded] }
    return [list $body rounded]
}

proc ::tclutils::tumindmap::parse {text} {
    set nodes {}        ;# list of {id label shape}
    set edges {}        ;# list of {from to}
    set stack {}        ;# list of {indent id}, ancestors of the current line
    set counter 0
    set headerSeen 0

    foreach raw [split $text \n] {
        set expanded [string map [list \t "    "] $raw]
        set body [string trim $expanded]
        if {$body eq "" || [string match {%%*} $body]} continue
        if {!$headerSeen && [regexp -nocase {^mindmap\M} $body]} {
            set headerSeen 1
            continue
        }
        # decorator lines (icons, css classes) -> ignored in v1
        if {[regexp {^(::icon|class)\M} $body]} continue

        set indent [expr {[string length $expanded] \
                          - [string length [string trimleft $expanded]]}]

        lassign [_decode $body] label shape
        set id "n[incr counter]"
        lappend nodes [list $id $label $shape]

        # pop siblings/deeper entries; what remains on top is the parent
        while {[llength $stack]
               && [lindex [lindex $stack end] 0] >= $indent} {
            set stack [lrange $stack 0 end-1]
        }
        if {[llength $stack]} {
            lappend edges [list [lindex [lindex $stack end] 1] $id]
        }
        lappend stack [list $indent $id]
    }

    if {![llength $nodes]} { _err EMPTY "no nodes found in mindmap" }

    set d [::tclutils::tudiagram::create -direction TB]
    foreach n $nodes {
        lassign $n id label shape
        set d [::tclutils::tudiagram::addNode $d $id -label $label -shape $shape]
    }
    foreach e $edges {
        lassign $e f t
        set d [::tclutils::tudiagram::addEdge $d $f $t -arrow none]
    }
    return $d
}

package provide tclutils::tumindmap 0.1
