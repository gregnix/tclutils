# tumermaid-0.1.tm – a small Mermaid *flowchart* frontend for tudiagram.
#
# Parses the common subset of Mermaid's `graph`/`flowchart` syntax into a
# tudiagram model dict, so a ```mermaid block can render natively through the
# pure-Tcl engine (SVG or PNG) everywhere — no browser, no Node.
#
#   set m [::tclutils::tumermaid::parse $mermaidText]
#   ::tclutils::tudiagram::writeSvg $m out.svg
#
# Supported v1:
#   - header:  graph LR|RL|TB|TD|BT   /   flowchart ...   (RL->LR, BT->TB in v1)
#   - nodes:   A[box]  A(rounded)  A([stadium])  A((circle))  A{diamond}  A
#              ([], default -> box; (), ([]), (()) -> rounded; {} -> box (no
#              diamond shape in tudiagram v1); quotes are stripped)
#   - edges:   A --> B   A --- B   A -.-> B   A ==> B   (and --o/--x)
#              labels:  A -->|text| B   and   A -- text --> B
#   - chains:  A --> B --> C
#   - comments: %% ...     ;-separated statements
# Not supported (ignored): subgraph/style/classDef/class/click/linkStyle,
#   A & B grouping, diamond/circle as distinct shapes.
#
# Namespace: ::tclutils::tumermaid   Package: tclutils::tumermaid 0.1
# Errors:    {TCLUTILS TUMERMAID <REASON>}

package require Tcl 8.6-
package require tclutils::tudiagram 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tumermaid {
    namespace export parse
}

proc ::tclutils::tumermaid::_dir {d} {
    switch -- [string toupper $d] {
        LR      { return LR }
        RL      { return LR }
        TB - TD { return TB }
        BT      { return TB }
        default { return LR }
    }
}

proc ::tclutils::tumermaid::_unquote {s} {
    set s [string trim $s]
    if {[string length $s] >= 2 && [string index $s 0] eq "\"" \
            && [string index $s end] eq "\""} {
        set s [string range $s 1 end-1]
    }
    return $s
}

# Take a node spec from the front of s (upvar). Record id -> {shape label} in
# nodes (upvar). Returns the id and advances s; "" if no node is at the front.
proc ::tclutils::tumermaid::_takeNode {sVar nodesVar} {
    upvar 1 $sVar s $nodesVar nodes
    set s [string trimleft $s]
    set id ""; set shape ""; set label ""
    if {[regexp {^([A-Za-z0-9_]+)\(\[([^\]]*)\]\)(.*)$} $s -> id label rest]} {
        set shape rounded
    } elseif {[regexp {^([A-Za-z0-9_]+)\(\(([^)]*)\)\)(.*)$} $s -> id label rest]} {
        set shape rounded
    } elseif {[regexp {^([A-Za-z0-9_]+)\[([^\]]*)\](.*)$} $s -> id label rest]} {
        set shape box
    } elseif {[regexp {^([A-Za-z0-9_]+)\(([^)]*)\)(.*)$} $s -> id label rest]} {
        set shape rounded
    } elseif {[regexp {^([A-Za-z0-9_]+)\{([^\}]*)\}(.*)$} $s -> id label rest]} {
        set shape box
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
proc ::tclutils::tumermaid::_takeEdge {sVar} {
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

proc ::tclutils::tumermaid::parse {text args} {
    set dir LR
    set nodes [dict create]
    set edges {}
    set headerSeen 0
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
            if {[regexp {^(style|classDef|class|subgraph|end|click|linkStyle)\M} $stmt]} continue
            # normalise "A -- text --> B" forms to "A -->|text| B"
            regsub -all -- {--\s+([^|>]+?)\s+-->}  $stmt {-->|\1|}  stmt
            regsub -all -- {==\s+([^|>]+?)\s+==>}  $stmt {==>|\1|}  stmt
            regsub -all -- {-\.\s+([^|>]+?)\s+\.->} $stmt {-.->|\1|} stmt
            set s $stmt
            set from [_takeNode s nodes]
            if {$from eq ""} continue
            while {1} {
                set e [_takeEdge s]
                if {$e eq ""} break
                lassign $e arrow style elabel
                set to [_takeNode s nodes]
                if {$to eq ""} break
                lappend edges [list $from $to $arrow $style $elabel]
                set from $to
            }
        }
    }
    if {![dict size $nodes]} {
        return -code error -errorcode {TCLUTILS TUMERMAID EMPTY} \
            "no nodes found in mermaid source"
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
    return $m
}

package provide tclutils::tumermaid 0.1
