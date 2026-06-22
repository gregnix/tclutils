# tublock-0.1.tm -- parse a Mermaid `block-beta` diagram into a tclutils::tudiagram
# model (best-effort), so it can render natively (SVG or PNG) through the
# pure-Tcl engine -- no browser. It is one of the graph-type parsers the
# tclutils::tuflow facade dispatches to; you normally call tuflow::toPng /
# tuflow::toSvg rather than this module directly.
#
#   block ids on a line:  a b c            -> three boxes
#   shaped/labelled:      a["Text"]        -> box
#                         a("Text")        -> rounded
#                         a(("Text"))      -> circle
#                         a{"Text"}        -> diamond
#                         a{{"Text"}}      -> hexagon
#                         a(["Text"])      -> stadium
#                         a[("Text")]      -> cylinder
#   edges:                a --> b   a --- b   a -->|label| b   a -- label --> b
#   block:groupId ... end -> flattened (inner blocks kept, the group box not drawn)
#   columns N             -> ignored (layout hint)
#   space / space:N       -> ignored (empty grid cell)
#   style/classDef/class/click -> ignored
#
# v1 limitations (honest): the grid geometry of block-beta (columns, widths,
# `:N` spans, explicit placement) is NOT reproduced -- tudiagram lays the blocks
# out as a top-down graph. Group boundaries are flattened. Node shapes map to
# tudiagram box/rounded/circle/diamond/hexagon (subroutine [[..]] -> box).
#
# Namespace: ::tclutils::tublock   Package: tclutils::tublock 0.1
# Errors:    {TCLUTILS TUBLOCK <REASON>}   REASON in EMPTY

package require Tcl 8.6 9
package require tclutils::common
package require tclutils::tudiagram

namespace eval ::tclutils::tublock {
    namespace export parse
}

proc ::tclutils::tublock::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUBLOCK $reason] $msg
}

proc ::tclutils::tublock::_unquote {s} {
    set s [string trim $s]
    set n [string length $s]
    if {$n >= 2} {
        set a [string index $s 0]; set b [string index $s end]
        if {($a eq "\"" && $b eq "\"") || ($a eq "'" && $b eq "'")} {
            return [string range $s 1 end-1]
        }
    }
    return $s
}

# Split a block-declaration line into tokens, keeping bracketed/quoted spans
# (which may contain spaces) together.
proc ::tclutils::tublock::_tokens {line} {
    set toks {}; set cur ""; set depth 0; set inq 0
    foreach ch [split $line ""] {
        if {$inq} {
            append cur $ch
            if {$ch eq "\""} { set inq 0 }
            continue
        }
        switch -- $ch {
            "\"" { set inq 1; append cur $ch }
            "\[" - "(" - "\{" { incr depth; append cur $ch }
            "\]" - ")" - "\}" { if {$depth > 0} { incr depth -1 }; append cur $ch }
            " " - "\t" {
                if {$depth > 0} { append cur $ch } \
                elseif {$cur ne ""} { lappend toks $cur; set cur "" }
            }
            default { append cur $ch }
        }
    }
    if {$cur ne ""} { lappend toks $cur }
    return $toks
}

# Decode a block token into {id label shape}. A trailing :N span is dropped.
proc ::tclutils::tublock::_decode {tok} {
    regsub {:[0-9]+$} $tok {} tok
    if {[regexp {^([A-Za-z0-9_]+)\(\((.*)\)\)$}   $tok -> id inner]} { return [list $id [_unquote $inner] circle] }
    if {[regexp {^([A-Za-z0-9_]+)\(\[(.*)\]\)$}   $tok -> id inner]} { return [list $id [_unquote $inner] stadium] }
    if {[regexp {^([A-Za-z0-9_]+)\[\((.*)\)\]$}   $tok -> id inner]} { return [list $id [_unquote $inner] cylinder] }
    if {[regexp {^([A-Za-z0-9_]+)\[\[(.*)\]\]$}   $tok -> id inner]} { return [list $id [_unquote $inner] box] }
    if {[regexp {^([A-Za-z0-9_]+)\{\{(.*)\}\}$}   $tok -> id inner]} { return [list $id [_unquote $inner] hexagon] }
    if {[regexp {^([A-Za-z0-9_]+)\[(.*)\]$}       $tok -> id inner]} { return [list $id [_unquote $inner] box] }
    if {[regexp {^([A-Za-z0-9_]+)\((.*)\)$}       $tok -> id inner]} { return [list $id [_unquote $inner] rounded] }
    if {[regexp {^([A-Za-z0-9_]+)\{(.*)\}$}       $tok -> id inner]} { return [list $id [_unquote $inner] diamond] }
    return [list $tok $tok box]
}

proc ::tclutils::tublock::parse {text} {
    set order {}            ;# node ids, first-seen order
    array set label {}
    array set shape {}
    set edges {}            ;# {from to label arrow}

    set ensure {{tok oV lV sV} {
        upvar 1 $oV order $lV label $sV shape
        lassign [::tclutils::tublock::_decode $tok] id lbl shp
        if {![info exists shape($id)]} {
            lappend order $id; set shape($id) $shp; set label($id) $lbl
        } elseif {$lbl ne $id} {
            set label($id) $lbl; set shape($id) $shp
        }
        return $id
    }}

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {[regexp -nocase {^block-beta\M} $line]} continue
        if {[regexp -nocase {^columns\M} $line]} continue
        if {[regexp -nocase {^(style|classDef|class|click)\M} $line]} continue
        if {[regexp -nocase {^block:} $line]} continue        ;# group open -> flatten
        if {$line eq "end"} continue                          ;# group close

        # edges (checked before block declarations)
        if {[regexp {^(\S+)\s*-->\s*\|([^|]*)\|\s*(\S+)$} $line -> f lbl t]} {
            lappend edges [list [apply $ensure $f order label shape] \
                                [apply $ensure $t order label shape] [_unquote $lbl] end]
            continue
        }
        if {[regexp {^(\S+)\s+--\s+(.+?)\s+--+>\s+(\S+)$} $line -> f lbl t]} {
            lappend edges [list [apply $ensure $f order label shape] \
                                [apply $ensure $t order label shape] [_unquote $lbl] end]
            continue
        }
        if {[regexp {^(\S+)\s*[-.=]{2,}>\s*(\S+)$} $line -> f t]} {
            lappend edges [list [apply $ensure $f order label shape] \
                                [apply $ensure $t order label shape] "" end]
            continue
        }
        if {[regexp {^(\S+)\s*---\s*(\S+)$} $line -> f t]} {
            lappend edges [list [apply $ensure $f order label shape] \
                                [apply $ensure $t order label shape] "" none]
            continue
        }

        # otherwise: a block-declaration line (one or more block tokens)
        foreach tok [_tokens $line] {
            if {[regexp {^space(:[0-9]+)?$} $tok]} continue
            apply $ensure $tok order label shape
        }
    }

    if {![llength $order]} { _err EMPTY "no blocks found in block-beta source" }

    set d [::tclutils::tudiagram::create -direction TB]
    foreach id $order {
        set d [::tclutils::tudiagram::addNode $d $id -label $label($id) -shape $shape($id)]
    }
    foreach e $edges {
        lassign $e f t l a
        set d [::tclutils::tudiagram::addEdge $d $f $t -label $l -arrow $a]
    }
    return $d
}

package provide tclutils::tublock 0.1
