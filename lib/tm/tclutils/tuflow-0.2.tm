# tuflow-0.1.tm – a compact flowchart text syntax for tudiagram.
#
# Parses an arrow-based flowchart notation into a tudiagram model dict, so a
# fenced flowchart block can render natively through the pure-Tcl engine
# (SVG or PNG) everywhere — no browser, no Node.
#
#   set m [::tclutils::tuflow::parse $text]
#   ::tclutils::tudiagram::writeSvg $m out.svg
#
# The arrow notation is intentionally compatible with the common flowchart-in-
# markdown style, so many existing snippets parse as-is. tuflow implements its
# own (deliberately small) subset, not a third-party tool — see the limits below.
#
# Supported v1:
#   - header:  graph LR|RL|TB|TD|BT   /   flowchart ...   (TD->TB)
#   - nodes:   A[box] A(rounded) A([stadium]) A((circle)) A{diamond}
#              A{{hexagon}} A[(database)] A[[subroutine]]  (mapped to the
#              tudiagram shapes box/rounded/stadium/circle/diamond/hexagon/
#              cylinder; subroutine -> box; quotes are stripped)
#   - edges:   A --> B   A --- B   A -.-> B   A ==> B   (and --o/--x)
#              labels:  A -->|text| B   and   A -- text --> B
#   - chains:  A --> B --> C
#   - comments: %% ...     ;-separated statements
# Not supported (ignored): subgraph/style/classDef/class/click/linkStyle,
#   A & B grouping; parallelogram/trapezoid shapes fall back to box.
#
# Namespace: ::tclutils::tuflow   Package: tclutils::tuflow 0.2
# Errors:    {TCLUTILS TUFLOW <REASON>}

package require Tcl 8.6-
package require tclutils::tudiagram 0.2

namespace eval ::tclutils {}
namespace eval ::tclutils::tuflow {
    namespace export parse toSvg toPng writeSvg writePng
}

proc ::tclutils::tuflow::_dir {d} {
    switch -- [string toupper $d] {
        LR      { return LR }
        RL      { return RL }
        TB - TD { return TB }
        BT      { return BT }
        default { return LR }
    }
}

proc ::tclutils::tuflow::_unquote {s} {
    set s [string trim $s]
    if {[string length $s] >= 2 && [string index $s 0] eq "\"" \
            && [string index $s end] eq "\""} {
        set s [string range $s 1 end-1]
    }
    return $s
}

# Take a node spec from the front of s (upvar). Record id -> {shape label} in
# nodes (upvar). Returns the id and advances s; "" if no node is at the front.
proc ::tclutils::tuflow::_takeNode {sVar nodesVar} {
    upvar 1 $sVar s $nodesVar nodes
    set s [string trimleft $s]
    set id ""; set shape ""; set label ""
    if {[regexp {^([A-Za-z0-9_]+)\[\[([^\]]*)\]\](.*)$} $s -> id label rest]} {
        set shape box       ;# [[..]] subroutine -> box
    } elseif {[regexp {^([A-Za-z0-9_]+)\[\(([^)]*)\)\](.*)$} $s -> id label rest]} {
        set shape cylinder  ;# [(..)] database
    } elseif {[regexp {^([A-Za-z0-9_]+)\(\[([^\]]*)\]\)(.*)$} $s -> id label rest]} {
        set shape stadium   ;# ([..]) stadium
    } elseif {[regexp {^([A-Za-z0-9_]+)\(\(([^)]*)\)\)(.*)$} $s -> id label rest]} {
        set shape circle    ;# ((..)) circle
    } elseif {[regexp {^([A-Za-z0-9_]+)\{\{([^\}]*)\}\}(.*)$} $s -> id label rest]} {
        set shape hexagon   ;# {{..}} hexagon
    } elseif {[regexp {^([A-Za-z0-9_]+)\[([^\]]*)\](.*)$} $s -> id label rest]} {
        set shape box       ;# [..] rectangle
    } elseif {[regexp {^([A-Za-z0-9_]+)\(([^)]*)\)(.*)$} $s -> id label rest]} {
        set shape rounded   ;# (..) rounded
    } elseif {[regexp {^([A-Za-z0-9_]+)\{([^\}]*)\}(.*)$} $s -> id label rest]} {
        set shape diamond   ;# {..} decision
    } elseif {[regexp {^([A-Za-z0-9_]+)(.*)$} $s -> id rest]} {
        set shape ""
    } else {
        return ""
    }
    set s $rest
    if {$shape ne ""} {
        dict set nodes $id [dict create shape $shape label [_unquote $label]]
    } elseif {![dict exists $nodes $id]} {
        dict set nodes $id [dict create shape box label $id]
    }
    return $id
}

# Take an edge operator (+ optional |label|) from the front of s (upvar).
# Returns {arrow style label} or "" if none. Advances s.
proc ::tclutils::tuflow::_takeEdge {sVar} {
    upvar 1 $sVar s
    set s [string trimleft $s]
    if {![regexp {^(-\.->|-\.-|-->|---|==>|===|--o|--x)\s*(?:\|([^|]*)\|)?\s*(.*)$} \
            $s -> op label rest]} {
        return ""
    }
    set s $rest
    set arrow [expr {$op in {-.-> --> ==> --o --x} ? "end" : "none"}]
    set style solid
    if {[string match {*.*} $op]} {
        set style dotted
    } elseif {[string match {=*} $op]} {
        set style thick
    }
    return [list $arrow $style [_unquote $label]]
}

proc ::tclutils::tuflow::parse {text args} {
    set dir LR
    set nodes [dict create]
    set edges {}
    set headerSeen 0
    # tuflow renders flowcharts only. Detect other Mermaid diagram types on the
    # first meaningful line and reject them with a clear errorCode, so callers
    # (e.g. docir) can fall back to the source instead of mis-parsing every line
    # into a flowchart node.
    foreach _probeRaw [split $text \n] {
        set _probe [string trim $_probeRaw]
        if {$_probe eq "" || [string match {%%*} $_probe]} continue
        # state diagrams are graphs too: delegate to the tustate parser, which
        # also returns a tudiagram model. (lazy require; docir keeps calling
        # tuflow::parse and gets a renderable model either way.)
        if {[regexp -nocase {^stateDiagram(-v2)?\M} $_probe]} {
            package require tclutils::tustate
            return [::tclutils::tustate::parse $text]
        }
        if {[regexp -nocase {^requirementDiagram\M} $_probe]} {
            package require tclutils::turequirement
            return [::tclutils::turequirement::parse $text]
        }
        if {[regexp -nocase {^erDiagram\M} $_probe]} {
            package require tclutils::tuer
            return [::tclutils::tuer::parse $text]
        }
        if {[regexp -nocase {^classDiagram(-v2)?\M} $_probe]} {
            package require tclutils::tuclass
            return [::tclutils::tuclass::parse $text]
        }
        if {[regexp -nocase {^mindmap\M} $_probe]} {
            package require tclutils::tumindmap
            return [::tclutils::tumindmap::parse $text]
        }
        if {[regexp -nocase {^C4(Context|Container|Component|Dynamic|Deployment)\M} $_probe]} {
            package require tclutils::tuc4
            return [::tclutils::tuc4::parse $text]
        }
        if {[regexp -nocase {^block-beta\M} $_probe]} {
            package require tclutils::tublock
            return [::tclutils::tublock::parse $text]
        }
        if {[regexp -nocase {^gitGraph\M} $_probe]} {
            package require tclutils::tugit
            return [::tclutils::tugit::parse $text]
        }
        if {[regexp -nocase {^architecture(-beta)?\M} $_probe]} {
            package require tclutils::tuarchitecture
            return [::tclutils::tuarchitecture::parse $text]
        }
        if {[regexp -nocase {^(sequenceDiagram|gantt|journey|pie|timeline|quadrantChart|sankey-beta|xychart-beta|kanban|packet(-beta)?|treemap(-beta)?|radar(-beta)?)\M} $_probe -> _kw]} {
            return -code error -errorcode {TCLUTILS TUFLOW UNSUPPORTED} \
                "Mermaid diagram type \"$_kw\" is not supported (tuflow renders flowcharts only)"
        }
        break
    }
    # Pre-scan: collect declared subgraph ids so an edge that targets a cluster
    # id (e.g. `A --> block`) can be dropped -- v1 does not draw edges to/from a
    # cluster, only the frame around its member nodes.
    set groupIds {}
    foreach _rl [split $text \n] {
        if {[regexp -nocase {^\s*subgraph\s+(\S+)} $_rl -> _gid]} { lappend groupIds $_gid }
    }
    set groupOrder {}       ;# declared subgraph ids, in order
    array set groupLabel {}
    array set groupMembers {}
    set groupStack {}       ;# open subgraphs, innermost last

    foreach rawline [split $text \n] {
        set line [string trim $rawline]
        if {$line eq "" || [string match {%%*} $line]} continue
        foreach stmt [split $line ";"] {
            set stmt [string trim $stmt]
            if {$stmt eq ""} continue
            if {!$headerSeen && [regexp {^(graph|flowchart)\s+([A-Za-z]+)} $stmt -> _ d]} {
                set dir [_dir $d]; set headerSeen 1; continue
            }
            if {!$headerSeen && [regexp {^(graph|flowchart)\M} $stmt]} {
                set headerSeen 1; continue
            }
            # subgraph open: push onto the group stack (nested subgraphs allowed)
            if {[regexp -nocase {^subgraph\s+(\S+)(?:\s*\[([^\]]*)\])?\s*$} $stmt -> gid glabel]} {
                if {$glabel eq ""} { set glabel $gid }
                if {$gid ni $groupOrder} {
                    lappend groupOrder $gid
                    set groupLabel($gid) $glabel
                    set groupMembers($gid) {}
                }
                lappend groupStack $gid
                continue
            }
            if {[regexp -nocase {^end\M} $stmt]} {
                if {[llength $groupStack]} { set groupStack [lrange $groupStack 0 end-1] }
                continue
            }
            # `direction` inside a subgraph is v1-ignored (global direction wins)
            if {[regexp -nocase {^direction\M} $stmt]} continue
            if {[regexp {^(style|classDef|class|click|linkStyle)\M} $stmt]} continue
            # normalise "A -- text --> B" forms to "A -->|text| B"
            regsub -all -- {--\s+([^|>]+?)\s+-->}  $stmt {-->|\1|}  stmt
            regsub -all -- {==\s+([^|>]+?)\s+==>}  $stmt {==>|\1|}  stmt
            regsub -all -- {-\.\s+([^|>]+?)\s+\.->} $stmt {-.->|\1|} stmt
            set s $stmt
            set from [_takeNode s nodes]
            if {$from eq ""} continue
            if {$from in $groupIds} continue   ;# stmt targets a cluster id
            if {[llength $groupStack]} {
                foreach _g $groupStack { lappend groupMembers($_g) $from }
            }
            while {1} {
                set e [_takeEdge s]
                if {$e eq ""} break
                lassign $e arrow style elabel
                set to [_takeNode s nodes]
                if {$to eq ""} break
                if {$to in $groupIds} break    ;# edge to a cluster id (v1: drop)
                if {[llength $groupStack]} {
                    foreach _g $groupStack { lappend groupMembers($_g) $to }
                }
                lappend edges [list $from $to $arrow $style $elabel]
                set from $to
            }
        }
    }
    # drop phantom nodes created from cluster ids referenced in edges
    foreach gid $groupIds { catch {dict unset nodes $gid} }
    if {![dict size $nodes]} {
        return -code error -errorcode {TCLUTILS TUFLOW EMPTY} \
            "no nodes found in flowchart source"
    }
    set m [::tclutils::tudiagram::create -direction $dir]
    dict for {id spec} $nodes {
        set m [::tclutils::tudiagram::addNode $m $id \
            -label [dict get $spec label] -shape [dict get $spec shape]]
    }
    foreach e $edges {
        lassign $e from to arrow style elabel
        set m [::tclutils::tudiagram::addEdge $m $from $to \
            -arrow $arrow -style $style -label $elabel]
    }
    # clusters: a frame is drawn around each subgraph's member nodes (tudiagram
    # >= 0.4; with 0.3 addGroup is absent, so this is a no-op via catch).
    foreach gid $groupOrder {
        set real {}
        foreach mid [lsort -unique $groupMembers($gid)] {
            if {[dict exists $nodes $mid]} { lappend real $mid }
        }
        if {[llength $real] && [llength [info commands ::tclutils::tudiagram::addGroup]]} {
            set m [::tclutils::tudiagram::addGroup $m $gid \
                -label $groupLabel($gid) -members $real]
        }
    }
    return $m
}

# --- render facade -----------------------------------------------------------
#
# parse (above) is graph-only: it returns a tudiagram model and rejects non-graph
# Mermaid types with {TCLUTILS TUFLOW UNSUPPORTED}. The facade below renders any
# supported diagram family to SVG or PNG, so a single call covers both the graph
# families (via tudiagram) and the non-graph families (currently pie, via tupie).
# Non-graph types are detected and dispatched here, before parse is reached.

proc ::tclutils::tuflow::_firstKeyword {text} {
    foreach raw [split $text \n] {
        set p [string trim $raw]
        if {$p eq "" || [string match {%%*} $p]} continue
        regexp {^(\S+)} $p -> kw
        return $kw
    }
    return ""
}

# Forward only the option keys a given backend understands (parseOptions is
# strict and would reject unknown keys).
proc ::tclutils::tuflow::_forward {arglist keys} {
    set out {}
    foreach {k v} $arglist {
        if {$k in $keys} { lappend out $k $v }
    }
    return $out
}

proc ::tclutils::tuflow::toSvg {text args} {
    if {[string match -nocase pie [_firstKeyword $text]]} {
        package require tclutils::tupie
        set m [::tclutils::tupie::parse $text]
        return [::tclutils::tupie::toSvg $m \
            {*}[_forward $args {-width -height -legend -fontfile -scale}]]
    }
    if {[string match -nocase xychart-beta [_firstKeyword $text]]} {
        package require tclutils::tuxychart
        set m [::tclutils::tuxychart::parse $text]
        return [::tclutils::tuxychart::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase quadrantChart [_firstKeyword $text]]} {
        package require tclutils::tuquadrant
        set m [::tclutils::tuquadrant::parse $text]
        return [::tclutils::tuquadrant::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase journey [_firstKeyword $text]]} {
        package require tclutils::tujourney
        set m [::tclutils::tujourney::parse $text]
        return [::tclutils::tujourney::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase timeline [_firstKeyword $text]]} {
        package require tclutils::tutimeline
        set m [::tclutils::tutimeline::parse $text]
        return [::tclutils::tutimeline::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[regexp -nocase {^sankey(-beta)?$} [_firstKeyword $text]]} {
        package require tclutils::tusankey
        set m [::tclutils::tusankey::parse $text]
        return [::tclutils::tusankey::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase gantt [_firstKeyword $text]]} {
        package require tclutils::tugantt
        set m [::tclutils::tugantt::parse $text]
        return [::tclutils::tugantt::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase sequenceDiagram [_firstKeyword $text]]} {
        package require tclutils::tusequence
        set m [::tclutils::tusequence::parse $text]
        return [::tclutils::tusequence::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[regexp -nocase {^radar(-beta)?$} [_firstKeyword $text]]} {
        package require tclutils::turadar
        set m [::tclutils::turadar::parse $text]
        return [::tclutils::turadar::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[regexp -nocase {^treemap(-beta)?$} [_firstKeyword $text]]} {
        package require tclutils::tutreemap
        set m [::tclutils::tutreemap::parse $text]
        return [::tclutils::tutreemap::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[regexp -nocase {^packet(-beta)?$} [_firstKeyword $text]]} {
        package require tclutils::tupacket
        set m [::tclutils::tupacket::parse $text]
        return [::tclutils::tupacket::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase kanban [_firstKeyword $text]]} {
        package require tclutils::tukanban
        set m [::tclutils::tukanban::parse $text]
        return [::tclutils::tukanban::toSvg $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    return [::tclutils::tudiagram::toSvg [parse $text]]
}

proc ::tclutils::tuflow::toPng {text args} {
    if {[string match -nocase pie [_firstKeyword $text]]} {
        package require tclutils::tupie
        set m [::tclutils::tupie::parse $text]
        return [::tclutils::tupie::toPng $m \
            {*}[_forward $args {-width -height -legend -fontfile -scale}]]
    }
    if {[string match -nocase xychart-beta [_firstKeyword $text]]} {
        package require tclutils::tuxychart
        set m [::tclutils::tuxychart::parse $text]
        return [::tclutils::tuxychart::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase quadrantChart [_firstKeyword $text]]} {
        package require tclutils::tuquadrant
        set m [::tclutils::tuquadrant::parse $text]
        return [::tclutils::tuquadrant::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase journey [_firstKeyword $text]]} {
        package require tclutils::tujourney
        set m [::tclutils::tujourney::parse $text]
        return [::tclutils::tujourney::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase timeline [_firstKeyword $text]]} {
        package require tclutils::tutimeline
        set m [::tclutils::tutimeline::parse $text]
        return [::tclutils::tutimeline::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[regexp -nocase {^sankey(-beta)?$} [_firstKeyword $text]]} {
        package require tclutils::tusankey
        set m [::tclutils::tusankey::parse $text]
        return [::tclutils::tusankey::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase gantt [_firstKeyword $text]]} {
        package require tclutils::tugantt
        set m [::tclutils::tugantt::parse $text]
        return [::tclutils::tugantt::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase sequenceDiagram [_firstKeyword $text]]} {
        package require tclutils::tusequence
        set m [::tclutils::tusequence::parse $text]
        return [::tclutils::tusequence::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[regexp -nocase {^radar(-beta)?$} [_firstKeyword $text]]} {
        package require tclutils::turadar
        set m [::tclutils::turadar::parse $text]
        return [::tclutils::turadar::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[regexp -nocase {^treemap(-beta)?$} [_firstKeyword $text]]} {
        package require tclutils::tutreemap
        set m [::tclutils::tutreemap::parse $text]
        return [::tclutils::tutreemap::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[regexp -nocase {^packet(-beta)?$} [_firstKeyword $text]]} {
        package require tclutils::tupacket
        set m [::tclutils::tupacket::parse $text]
        return [::tclutils::tupacket::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    if {[string match -nocase kanban [_firstKeyword $text]]} {
        package require tclutils::tukanban
        set m [::tclutils::tukanban::parse $text]
        return [::tclutils::tukanban::toPng $m \
            {*}[_forward $args {-width -height -fontfile -scale}]]
    }
    set m [parse $text]
    set ff ""
    foreach {k v} $args { if {$k eq "-fontfile"} { set ff $v } }
    if {$ff ne ""} { set m [::tclutils::tudiagram::setMeta $m -fontfile $ff] }
    return [::tclutils::tudiagram::toPng $m {*}[_forward $args {-scale}]]
}

proc ::tclutils::tuflow::writeSvg {text file args} {
    set svg [toSvg $text {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tuflow::writePng {text file args} {
    set png [toPng $text {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tuflow 0.2
