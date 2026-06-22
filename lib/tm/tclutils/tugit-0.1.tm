# tugit-0.1.tm -- parse a Mermaid `gitGraph` into a tclutils::tudiagram model
# (best-effort), so it can render natively (SVG or PNG) through the pure-Tcl
# engine -- no browser. It is one of the graph-type parsers the tclutils::tuflow
# facade dispatches to; you normally call tuflow::toPng / tuflow::toSvg rather
# than this module directly.
#
#   commit                       -> a commit node on the current branch
#   commit id: "X" tag: "T"      -> node labelled X (with the tag appended)
#   branch <name>                -> create branch from current HEAD, switch to it
#   checkout <name>              -> switch the current branch
#   merge <name>                 -> merge commit with two parents (current HEAD
#                                   and <name>'s HEAD)
#   cherry-pick id: "X"          -> a commit node on the current branch
#
# Commits become nodes; an edge runs from each parent commit to its child. The
# default branch is `main`; the layout direction is LR unless the header says
# `gitGraph TB:`.
#
# v1 limitations (honest): the characteristic branch lanes / swimlanes of a git
# graph are NOT drawn -- tudiagram lays the commits out as a generic left-to-
# right DAG, but each commit is filled in its branch's colour so branches stay
# distinguishable. Commit `type:` styling is ignored; commit nodes are rounded,
# merge nodes are boxes.
#
# Namespace: ::tclutils::tugit   Package: tclutils::tugit 0.1
# Errors:    {TCLUTILS TUGIT <REASON>}   REASON in EMPTY

package require Tcl 8.6 9
package require tclutils::common
package require tclutils::tudiagram

namespace eval ::tclutils::tugit {
    namespace export parse
    # {fill stroke} per branch, cycled in branch-declaration order
    variable branchColors {
        {#e3f2fd #1565c0} {#fde8e8 #c62828} {#e8f5e9 #2e7d32}
        {#fff3e0 #e65100} {#f3e5f5 #6a1b9a} {#e0f7fa #00838f}
    }
}

proc ::tclutils::tugit::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUGIT $reason] $msg
}

# Ensure the branch has a colour (assigned on first use) and return it as a
# tudiagram node -style dict {fill F stroke S}.
proc ::tclutils::tugit::_branchStyle {branch bcolorVar bciVar} {
    variable branchColors
    upvar 1 $bcolorVar bcolor $bciVar bci
    if {![info exists bcolor($branch)]} {
        set bcolor($branch) [lindex $branchColors [expr {$bci % [llength $branchColors]}]]
        incr bci
    }
    return [list fill [lindex $bcolor($branch) 0] stroke [lindex $bcolor($branch) 1]]
}

proc ::tclutils::tugit::parse {text} {
    set dir LR
    set order {}            ;# node ids, first-seen order
    array set label {}
    array set shape {}
    set edges {}            ;# {from to}
    array set head {}       ;# branch -> head commit id ("" = none yet)
    array set style {}      ;# node id -> -style dict
    array set bcolor {}     ;# branch -> {fill stroke}
    set bci 0
    set cur main
    set head(main) ""
    _branchStyle main bcolor bci    ;# main gets the first colour
    set n 0
    set sawHeader 0

    # add a node once; ignore a duplicate explicit id (avoids tudiagram DUPID)
    set add {{id lbl shp oV lV sV} {
        upvar 1 $oV order $lV label $sV shape
        if {![info exists shape($id)]} {
            lappend order $id; set shape($id) $shp
            set label($id) [expr {$lbl ne "" ? $lbl : $id}]
        }
    }}

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {!$sawHeader && [regexp -nocase {^gitGraph\M(.*)$} $line -> rest]} {
            set sawHeader 1
            if {[regexp -nocase {\mTB\M} $rest]} { set dir TB }
            continue
        }

        if {[regexp -nocase {^commit\M(.*)$} $line -> rest]} {
            set cid ""; set tag ""
            regexp {id:\s*"([^"]*)"}  $rest -> cid
            regexp {tag:\s*"([^"]*)"} $rest -> tag
            if {$cid ne ""} { set id $cid } else { set id "c[incr n]" }
            set lbl [expr {$cid ne "" ? $cid : $id}]
            if {$tag ne ""} { append lbl " \[$tag\]" }
            apply $add $id $lbl rounded order label shape
            set style($id) [_branchStyle $cur bcolor bci]
            if {$head($cur) ne ""} { lappend edges [list $head($cur) $id] }
            set head($cur) $id
            continue
        }
        if {[regexp -nocase {^branch\s+(\S+)} $line -> bn]} {
            if {![info exists head($bn)]} { set head($bn) $head($cur) }
            _branchStyle $bn bcolor bci
            set cur $bn
            continue
        }
        if {[regexp -nocase {^checkout\s+(\S+)} $line -> bn]} {
            if {![info exists head($bn)]} { set head($bn) "" }
            set cur $bn
            continue
        }
        if {[regexp -nocase {^merge\s+(\S+)(.*)$} $line -> bn rest]} {
            set cid ""; regexp {id:\s*"([^"]*)"} $rest -> cid
            if {$cid ne ""} { set id $cid } else { set id "c[incr n]" }
            apply $add $id "merge $bn" box order label shape
            set style($id) [_branchStyle $cur bcolor bci]
            if {$head($cur) ne ""} { lappend edges [list $head($cur) $id] }
            if {[info exists head($bn)] && $head($bn) ne ""} {
                lappend edges [list $head($bn) $id]
            }
            set head($cur) $id
            continue
        }
        if {[regexp -nocase {^cherry-pick\M(.*)$} $line -> rest]} {
            set cid ""; regexp {id:\s*"([^"]*)"} $rest -> cid
            set id "c[incr n]"
            apply $add $id [expr {$cid ne "" ? "pick $cid" : "cherry-pick"}] \
                rounded order label shape
            set style($id) [_branchStyle $cur bcolor bci]
            if {$head($cur) ne ""} { lappend edges [list $head($cur) $id] }
            set head($cur) $id
            continue
        }
    }

    if {![llength $order]} { _err EMPTY "no commits found in gitGraph source" }

    set d [::tclutils::tudiagram::create -direction $dir]
    foreach id $order {
        set d [::tclutils::tudiagram::addNode $d $id -label $label($id) -shape $shape($id) \
            -style [expr {[info exists style($id)] ? $style($id) : {}}]]
    }
    foreach e $edges {
        lassign $e f t
        set d [::tclutils::tudiagram::addEdge $d $f $t -arrow end]
    }
    return $d
}

package provide tclutils::tugit 0.1
