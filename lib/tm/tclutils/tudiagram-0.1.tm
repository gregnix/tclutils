# tudiagram-0.1.tm – box-and-arrow diagrams in pure Tcl.
#
# Model (dict) -> layered layout -> render on the shared canvas protocol.
# The render layer talks ONLY to the congruent canvas API (tusvg 0.2 OR
# tupngdraw): the same render proc emits SVG or PNG, the constructor is the only
# difference. Box sizing uses the shared monospace text metric, so geometry is
# backend-independent.
#
# Scope v1: layered layout for DAGs. Long edges (span > 1 rank) are routed
# through dummy lane nodes so they no longer disappear behind intermediate
# boxes; within-rank order is improved by a few barycentre sweeps to reduce
# crossings. Cycles are broken best-effort (back-edges drawn reversed). Cross-
# axis coordinates are simple ordered stacking (no Brandes-Köpf alignment), so
# long chains can still wiggle a little. Self-loops are not drawn. Shapes: box,
# rounded. Directions: LR, TB.
#
# Builder procs are functional: they return the updated diagram dict
#   (use:  set d [tudiagram::addNode $d id -label X]).
#
# Namespace: ::tclutils::tudiagram   Package: tclutils::tudiagram 0.1
# Errors:    {TCLUTILS TUDIAGRAM <REASON>}   REASON in DUPID NONODE EMPTY DIR ARG
# Tcl 8.6+/9.x. Depends only on tclutils::common; render needs a canvas object
# (tusvg or tupngdraw) but the model/layout do not.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tudiagram {
    namespace export create addNode addEdge setMeta validate layout \
        render toSvg toPng writeSvg writePng theme
    variable themes
    # Colours are 6-digit hex on purpose: the swap-safe intersection of the
    # tusvg and tupngdraw colour inputs.
    set themes [dict create \
        default [dict create fill #f4f4f5 stroke #52525b text #18181b \
                    edge #71717a font 2 pad 14] \
        pipeline [dict create fill #e3f2fd stroke #1565c0 text #0d47a1 \
                    edge #555555 font 2 pad 14] \
        mono    [dict create fill #ffffff stroke #000000 text #000000 \
                    edge #000000 font 2 pad 14]]
}

proc ::tclutils::tudiagram::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUDIAGRAM $reason] $msg
}

# --- model -----------------------------------------------------------------

proc ::tclutils::tudiagram::create {args} {
    set o [::tclutils::common::parseOptions \
        {-title {} -direction LR -theme default} {*}$args]
    if {[dict get $o -direction] ni {LR TB}} {
        _err DIR "direction must be LR or TB (v1)"
    }
    return [dict create \
        version 1 \
        meta [dict create \
            title     [dict get $o -title] \
            direction [dict get $o -direction] \
            theme     [dict get $o -theme] \
            nodeGap 30 rankGap 70 padding 20] \
        nodes {} edges {}]
}

proc ::tclutils::tudiagram::setMeta {d args} {
    set m [dict get $d meta]
    foreach {k v} $args {
        set key [string trimleft $k -]
        if {$key eq "direction" && $v ni {LR TB}} { _err DIR "direction must be LR or TB" }
        dict set m $key $v
    }
    dict set d meta $m
    return $d
}

proc ::tclutils::tudiagram::addNode {d id args} {
    foreach n [dict get $d nodes] {
        if {[dict get $n id] eq $id} { _err DUPID "duplicate node id: $id" }
    }
    set o [::tclutils::common::parseOptions \
        {-label {} -shape box -style {}} {*}$args]
    set label [dict get $o -label]
    if {$label eq ""} { set label $id }
    if {[dict get $o -shape] ni {box rounded}} {
        _err ARG "shape must be box or rounded (v1)"
    }
    dict lappend d nodes [dict create \
        id $id label $label shape [dict get $o -shape] style [dict get $o -style]]
    return $d
}

proc ::tclutils::tudiagram::addEdge {d from to args} {
    set o [::tclutils::common::parseOptions {-label {} -style solid -arrow end} {*}$args]
    dict lappend d edges [dict create \
        from $from to $to label [dict get $o -label] \
        style [dict get $o -style] arrow [dict get $o -arrow]]
    return $d
}

# --- validate --------------------------------------------------------------

proc ::tclutils::tudiagram::validate {d} {
    set problems {}
    set ids {}
    foreach n [dict get $d nodes] { lappend ids [dict get $n id] }
    if {![llength $ids]} { lappend problems {EMPTY no nodes} }
    foreach e [dict get $d edges] {
        if {[dict get $e from] ni $ids} {
            lappend problems [list NONODE "edge from unknown node: [dict get $e from]"]
        }
        if {[dict get $e to] ni $ids} {
            lappend problems [list NONODE "edge to unknown node: [dict get $e to]"]
        }
    }
    return $problems
}

# --- layout: layered -------------------------------------------------------
#
# Returns a new dict where each node carries x y width height (top-left origin)
# and each edge carries `back` (1 if reversed to break a cycle). Geometry is in
# pixels and needs no canvas (text metric is the fixed monospace grid).

proc ::tclutils::tudiagram::_textMetrics {label font} {
    # font = tupngdraw/tusvg -scale. char cell 6x8 px. Returns {w h} of the text.
    set lines [split $label \n]
    set maxc 0
    foreach ln $lines { set maxc [expr {max($maxc, [string length $ln])}] }
    return [list [expr {$maxc * 6 * $font}] [expr {[llength $lines] * 8 * $font}]]
}

# --- layout helpers --------------------------------------------------------

# DFS cycle detection. Marks back-edges (by edge index) in the array named by
# backName. adjName maps id -> list of {targetId edgeIndex}.
proc ::tclutils::tudiagram::_dfsVisit {id adjName colorName backName} {
    upvar 1 $adjName adj $colorName color $backName back
    set color($id) gray
    foreach pair $adj($id) {
        lassign $pair t eidx
        if {$color($t) eq "gray"} {
            set back($eidx) 1
        } elseif {$color($t) eq "white"} {
            _dfsVisit $t adj color back
        }
    }
    set color($id) black
}

# Order a rank's ids by the barycentre (mean position) of their neighbours in
# the adjacent rank. Ids without neighbours keep their current position. Stable
# on ties (lsort preserves input order), so the sweep converges instead of
# oscillating.
proc ::tclutils::tudiagram::_orderByBary {ids nbrName posName} {
    upvar 1 $nbrName nbr $posName pos
    set keyed {}
    foreach id $ids {
        if {[info exists nbr($id)] && [llength $nbr($id)]} {
            set sum 0.0
            foreach n $nbr($id) { set sum [expr {$sum + $pos($n)}] }
            set k [expr {$sum / [llength $nbr($id)]}]
        } else {
            set k [expr {double($pos($id))}]
        }
        lappend keyed [list $k $id]
    }
    set out {}
    foreach item [lsort -real -index 0 $keyed] { lappend out [lindex $item 1] }
    return $out
}

# --- layout: layered with dummy nodes for long edges -----------------------
#
# Each real node gets x y width height (top-left origin). Each edge gets a
# `points` polyline (already clipped to the source/target box borders, routed
# through dummy lane points for spans > 1 rank) and `arrowStart` (1 if the
# arrowhead is at the first point, e.g. for a back-edge). Geometry needs no
# canvas (the text metric is the fixed monospace grid).

proc ::tclutils::tudiagram::layout {d} {
    foreach p [validate $d] {
        if {[lindex $p 0] eq "EMPTY"} { _err EMPTY "cannot lay out an empty diagram" }
    }
    set meta    [dict get $d meta]
    set dir     [dict get $meta direction]
    set th      [theme [dict get $meta theme]]
    set font    [dict get $th font]
    set pad     [dict get $th pad]
    set nodeGap [dict get $meta nodeGap]
    set rankGap [dict get $meta rankGap]
    set padding [dict get $meta padding]
    set laneH   16

    # real nodes: insertion order + box size from label
    set order {}
    foreach n [dict get $d nodes] {
        set id [dict get $n id]
        lappend order $id
        set NODEDICT($id) $n
        lassign [_textMetrics [dict get $n label] $font] tw thh
        set W($id) [expr {$tw + 2*$pad}]
        set H($id) [expr {$thh + 2*$pad}]
        set real($id) 1
    }

    # adjacency for cycle detection (ignore self-loops / unknown endpoints)
    foreach id $order { set adj($id) {} }
    set edges [dict get $d edges]
    set ei 0
    foreach e $edges {
        set f [dict get $e from]; set t [dict get $e to]
        if {[info exists real($f)] && [info exists real($t)] && $f ne $t} {
            lappend adj($f) [list $t $ei]
        }
        incr ei
    }
    foreach id $order { set color($id) white }
    array set backedge {}
    foreach id $order { if {$color($id) eq "white"} { _dfsVisit $id adj color backedge } }

    # longest-path rank over forward (non-back) edges
    foreach id $order { set rank($id) 0; set fadj($id) {}; set indeg($id) 0 }
    set ei 0
    foreach e $edges {
        set f [dict get $e from]; set t [dict get $e to]
        if {[info exists real($f)] && [info exists real($t)] && $f ne $t \
                && ![info exists backedge($ei)]} {
            lappend fadj($f) $t
            incr indeg($t)
        }
        incr ei
    }
    set queue {}
    foreach id $order { if {$indeg($id) == 0} { lappend queue $id } }
    while {[llength $queue]} {
        set queue [lassign $queue u]
        foreach v $fadj($u) {
            if {$rank($v) < $rank($u)+1} { set rank($v) [expr {$rank($u)+1}] }
            if {[incr indeg($v) -1] == 0} { lappend queue $v }
        }
    }
    set maxRank 0
    foreach id $order { set maxRank [expr {max($maxRank,$rank($id))}] }

    # rank membership (real nodes first, in insertion order)
    for {set r 0} {$r <= $maxRank} {incr r} { set members($r) {} }
    foreach id $order { lappend members($rank($id)) $id }

    # build dummy nodes for long edges + the per-edge chain + segment graph
    set seglist {}
    set dcount 0
    set ei 0
    foreach e $edges {
        set f [dict get $e from]; set t [dict get $e to]
        if {![info exists real($f)] || ![info exists real($t)] || $f eq $t} {
            set chain($ei) {}; set arrowStart($ei) 0; incr ei; continue
        }
        if {$rank($f) <= $rank($t)} {
            set lo $f; set hi $t; set arrowStart($ei) 0
        } else {
            set lo $t; set hi $f; set arrowStart($ei) 1
        }
        set rlo $rank($lo); set rhi $rank($hi)
        set ch [list $lo]
        set prev $lo
        for {set r [expr {$rlo+1}]} {$r < $rhi} {incr r} {
            set dn "__d[incr dcount]"
            set rank($dn) $r
            set W($dn) 1; set H($dn) $laneH
            lappend members($r) $dn
            lappend seglist [list $prev $dn]
            lappend ch $dn
            set prev $dn
        }
        if {$rlo != $rhi} { lappend seglist [list $prev $hi] }
        lappend ch $hi
        set chain($ei) $ch
        incr ei
    }

    # barycentre ordering within ranks (real + dummy), a few sweeps
    foreach s $seglist {
        lassign $s a b
        lappend nextN($a) $b
        lappend prevN($b) $a
    }
    for {set r 0} {$r <= $maxRank} {incr r} {
        set i 0; foreach id $members($r) { set pos($id) $i; incr i }
    }
    for {set it 0} {$it < 4} {incr it} {
        for {set r 1} {$r <= $maxRank} {incr r} {
            set members($r) [_orderByBary $members($r) prevN pos]
            set i 0; foreach id $members($r) { set pos($id) $i; incr i }
        }
        for {set r [expr {$maxRank-1}]} {$r >= 0} {incr r -1} {
            set members($r) [_orderByBary $members($r) nextN pos]
            set i 0; foreach id $members($r) { set pos($id) $i; incr i }
        }
    }

    # coordinates: main axis = rank columns; cross axis = stacked order
    for {set r 0} {$r <= $maxRank} {incr r} {
        set ms 1
        foreach id $members($r) {
            if {[info exists real($id)]} {
                set md [expr {$dir eq "LR" ? $W($id) : $H($id)}]
                set ms [expr {max($ms,$md)}]
            }
        }
        set mainSize($r) $ms
    }
    set baseMain $padding
    for {set r 0} {$r <= $maxRank} {incr r} {
        set rankMain($r) $baseMain
        set baseMain [expr {$baseMain + $mainSize($r) + $rankGap}]
    }
    for {set r 0} {$r <= $maxRank} {incr r} {
        set cross $padding
        foreach id $members($r) {
            if {[info exists real($id)]} {
                set w $W($id); set h $H($id)
                if {$dir eq "LR"} {
                    set X($id) [expr {$rankMain($r) + ($mainSize($r)-$w)/2.0}]
                    set Y($id) $cross
                    set cross [expr {$cross + $h + $nodeGap}]
                } else {
                    set X($id) $cross
                    set Y($id) [expr {$rankMain($r) + ($mainSize($r)-$h)/2.0}]
                    set cross [expr {$cross + $w + $nodeGap}]
                }
                set CX($id) [expr {$X($id)+$w/2.0}]
                set CY($id) [expr {$Y($id)+$h/2.0}]
            } else {
                if {$dir eq "LR"} {
                    set CX($id) [expr {$rankMain($r)+$mainSize($r)/2.0}]
                    set CY($id) [expr {$cross + $laneH/2.0}]
                } else {
                    set CX($id) [expr {$cross + $laneH/2.0}]
                    set CY($id) [expr {$rankMain($r)+$mainSize($r)/2.0}]
                }
                set cross [expr {$cross + $laneH + $nodeGap}]
            }
        }
    }

    # edge waypoints: clip first/last segment to the box borders
    set ei 0
    foreach e $edges {
        set ch $chain($ei)
        if {[llength $ch] < 2} { set EPTS($ei) {}; incr ei; continue }
        set id0 [lindex $ch 0]; set idn [lindex $ch end]
        set cs {}
        foreach id $ch { lappend cs [list $CX($id) $CY($id)] }
        lassign [lindex $cs 0] ax ay
        lassign [lindex $cs 1] nx ny
        set dx [expr {$nx-$ax}]; set dy [expr {$ny-$ay}]; set L [expr {hypot($dx,$dy)}]
        if {$L == 0} { set p0 [list $ax $ay] } else {
            set p0 [_boxExit $ax $ay [expr {$W($id0)/2.0}] [expr {$H($id0)/2.0}] \
                        [expr {$dx/$L}] [expr {$dy/$L}]]
        }
        lassign [lindex $cs end] bx by
        lassign [lindex $cs end-1] qx qy
        set dx [expr {$bx-$qx}]; set dy [expr {$by-$qy}]; set L [expr {hypot($dx,$dy)}]
        if {$L == 0} { set pn [list $bx $by] } else {
            set pn [_boxExit $bx $by [expr {$W($idn)/2.0}] [expr {$H($idn)/2.0}] \
                        [expr {-$dx/$L}] [expr {-$dy/$L}]]
        }
        set pts {}
        lappend pts {*}$p0
        for {set i 1} {$i < [llength $cs]-1} {incr i} { lappend pts {*}[lindex $cs $i] }
        lappend pts {*}$pn
        set EPTS($ei) $pts
        incr ei
    }

    # write back geometry + canvas size
    set Wd 0; set Hd 0
    set outNodes {}
    foreach id $order {
        set n $NODEDICT($id)
        dict set n x [expr {int(round($X($id)))}]
        dict set n y [expr {int(round($Y($id)))}]
        dict set n width  $W($id)
        dict set n height $H($id)
        lappend outNodes $n
        set Wd [expr {max($Wd, $X($id)+$W($id)+$padding)}]
        set Hd [expr {max($Hd, $Y($id)+$H($id)+$padding)}]
    }
    foreach id [array names CX] {
        set Wd [expr {max($Wd, $CX($id)+$padding)}]
        set Hd [expr {max($Hd, $CY($id)+$padding)}]
    }
    set outEdges {}; set ei 0
    foreach e $edges {
        dict set e points $EPTS($ei)
        dict set e arrowStart $arrowStart($ei)
        dict set e back [expr {[info exists backedge($ei)] ? 1 : 0}]
        lappend outEdges $e; incr ei
    }
    dict set d nodes $outNodes
    dict set d edges $outEdges
    dict set d meta width  [expr {int(ceil($Wd))}]
    dict set d meta height [expr {int(ceil($Hd))}]
    dict set d meta laid 1
    return $d
}

proc ::tclutils::tudiagram::theme {name} {
    variable themes
    if {[dict exists $themes $name]} { return [dict get $themes $name] }
    if {[string is list $name] && [llength $name] % 2 == 0 && [dict exists $name fill]} {
        return [dict merge [dict get $themes default] $name]
    }
    return [dict get $themes default]
}

proc ::tclutils::tudiagram::_nodeCenter {n} {
    list [expr {[dict get $n x]+[dict get $n width]/2.0}] \
         [expr {[dict get $n y]+[dict get $n height]/2.0}]
}

# exit point of a box (centre cx cy, half hw hh) along unit dir (ux uy)
proc ::tclutils::tudiagram::_boxExit {cx cy hw hh ux uy} {
    set tx [expr {$ux != 0 ? $hw/abs($ux) : 1e9}]
    set ty [expr {$uy != 0 ? $hh/abs($uy) : 1e9}]
    set t [expr {min($tx,$ty)}]
    return [list [expr {$cx+$ux*$t}] [expr {$cy+$uy*$t}]]
}

proc ::tclutils::tudiagram::render {d canvas} {
    if {![dict exists $d meta laid]} { set d [layout $d] }
    set th [theme [dict get $d meta theme]]
    set fillC   [dict get $th fill]
    set strokeC [dict get $th stroke]
    set textC   [dict get $th text]
    set edgeC   [dict get $th edge]
    set font    [dict get $th font]

    # edges first (under boxes): draw the precomputed polyline, then an arrowhead
    foreach e [dict get $d edges] {
        set pts [dict get $e points]
        if {[llength $pts] < 4} continue
        $canvas setstroke $edgeC
        $canvas setlinewidth 2
        for {set i 0} {$i < [llength $pts]-2} {incr i 2} {
            $canvas line \
                [expr {int([lindex $pts $i])}]   [expr {int([lindex $pts [expr {$i+1}]])}] \
                [expr {int([lindex $pts [expr {$i+2}]])}] [expr {int([lindex $pts [expr {$i+3}]])}] \
                -width 2
        }
        set lbl [dict get $e label]
        if {$lbl ne ""} {
            set ef 1
            set ns  [expr {[llength $pts]/2 - 1}]
            set mid [expr {($ns/2)*2}]
            set mx [expr {([lindex $pts $mid]+[lindex $pts [expr {$mid+2}]])/2.0}]
            set my [expr {([lindex $pts [expr {$mid+1}]]+[lindex $pts [expr {$mid+3}]])/2.0}]
            set tw  [$canvas textwidth $lbl -scale $ef]
            set tht [expr {8*$ef}]
            set lx [expr {int($mx-$tw/2.0)}]; set ly [expr {int($my-$tht/2.0)}]
            $canvas setfill white
            $canvas rect [expr {$lx-2}] [expr {$ly-1}] [expr {$lx+$tw+2}] [expr {$ly+$tht+1}] \
                -fill 1 -outline 0
            $canvas text $lx $ly $lbl -scale $ef -color $edgeC
        }
        if {[dict get $e arrow] eq "none"} continue
        if {[dict get $e arrowStart]} {
            set tx [lindex $pts 0]; set ty [lindex $pts 1]
            set fx [lindex $pts 2]; set fy [lindex $pts 3]
        } else {
            set tx [lindex $pts end-1]; set ty [lindex $pts end]
            set fx [lindex $pts end-3]; set fy [lindex $pts end-2]
        }
        set dx [expr {$tx-$fx}]; set dy [expr {$ty-$fy}]
        set L [expr {hypot($dx,$dy)}]
        if {$L == 0} continue
        set ux [expr {$dx/$L}]; set uy [expr {$dy/$L}]
        set asz 9; set awd 5
        set bxp [expr {$tx-$asz*$ux}]; set byp [expr {$ty-$asz*$uy}]
        set px [expr {-$uy}]; set py [expr {$ux}]
        $canvas setfill $edgeC
        $canvas polygon [list \
            [expr {int($tx)}] [expr {int($ty)}] \
            [expr {int($bxp+$awd*$px)}] [expr {int($byp+$awd*$py)}] \
            [expr {int($bxp-$awd*$px)}] [expr {int($byp-$awd*$py)}]] -fill 1 -outline 0
    }

    # boxes + labels
    foreach n [dict get $d nodes] {
        set x [dict get $n x]; set y [dict get $n y]
        set w [dict get $n width]; set h [dict get $n height]
        $canvas setfill $fillC
        $canvas setstroke $strokeC
        $canvas setlinewidth 2
        if {[dict get $n shape] eq "rounded"} {
            $canvas rect $x $y [expr {$x+$w}] [expr {$y+$h}] -fill 1 -outline 1 -rx 8 -ry 8
        } else {
            $canvas rect $x $y [expr {$x+$w}] [expr {$y+$h}] -fill 1 -outline 1
        }
        set lines [split [dict get $n label] \n]
        set lh [expr {8*$font}]
        set ty [expr {int($y + ($h - [llength $lines]*$lh)/2)}]
        foreach ln $lines {
            set tw [$canvas textwidth $ln -scale $font]
            set tx [expr {int($x + ($w-$tw)/2)}]
            $canvas text $tx $ty $ln -scale $font -color $textC
            incr ty $lh
        }
    }
    return $canvas
}

# --- convenience: render straight to SVG / PNG -----------------------------

proc ::tclutils::tudiagram::_canvas {d backend} {
    if {![dict exists $d meta laid]} { set d [layout $d] }
    set w [dict get $d meta width]; set h [dict get $d meta height]
    switch -- $backend {
        svg { package require tclutils::tusvg 0.2
              return [list $d [::tclutils::tusvg::new -width $w -height $h -background white]] }
        png { package require tclutils::tupngdraw
              return [list $d [::tclutils::tupngdraw::new -width $w -height $h -background white]] }
        default { _err ARG "backend must be svg or png" }
    }
}

proc ::tclutils::tudiagram::toSvg {d args} {
    lassign [_canvas $d svg] d c
    render $d $c
    return [$c data]
}
proc ::tclutils::tudiagram::toPng {d args} {
    lassign [_canvas $d png] d c
    render $d $c
    return [$c data]
}
proc ::tclutils::tudiagram::writeSvg {d file args} {
    lassign [_canvas $d svg] d c
    render $d $c
    return [$c write $file]
}
proc ::tclutils::tudiagram::writePng {d file args} {
    lassign [_canvas $d png] d c
    render $d $c
    return [$c write $file]
}

package provide tclutils::tudiagram 0.1
