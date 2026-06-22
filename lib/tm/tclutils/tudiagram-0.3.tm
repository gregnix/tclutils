# tudiagram-0.2.tm – box-and-arrow diagrams in pure Tcl.
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
# rounded, dot, circle, stadium, diamond, hexagon, cylinder. Directions: LR, TB,
# RL, BT. Per-node colours: addNode -style accepts a dict {fill ? stroke ? text ?}
# overriding the theme for that node. Edges: addEdge -style solid|dashed|dotted|thick,
#   -arrow end|none|both|start, and crow's-foot -startMark/-endMark,
# -arrow end|none|both|start.
#
# Labels: by default the dependency-free 6x8 bitmap font. OPTIONAL: pass
#   -fontfile <ttf|otf> to create; on the raster (PNG) backend the labels are
#   then rendered as real outlines via tupngdraw fillcontours. This needs the
#   third-party Glyphs package (A. Buratti, permissive licence) -- NOT bundled;
#   if it is absent the labels fall back to the bitmap. The SVG backend ignores
#   -fontfile (it uses the viewer font), and the layout metric stays 6x8 either
#   way, so SVG and PNG geometry remain congruent.
#
# Builder procs are functional: they return the updated diagram dict
#   (use:  set d [tudiagram::addNode $d id -label X]).
#
# Namespace: ::tclutils::tudiagram   Package: tclutils::tudiagram 0.2
# Errors:    {TCLUTILS TUDIAGRAM <REASON>}   REASON in DUPID NONODE EMPTY DIR ARG FONT
# Tcl 8.6+/9.x. Depends only on tclutils::common; render needs a canvas object
# (tusvg or tupngdraw) but the model/layout do not. The optional -fontfile path
# additionally needs the Glyphs package at render time.

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
        {-title {} -direction LR -theme default -fontfile {}} {*}$args]
    if {[dict get $o -direction] ni {LR TB RL BT}} {
        _err DIR "direction must be LR, TB, RL or BT"
    }
    return [dict create \
        version 1 \
        meta [dict create \
            title     [dict get $o -title] \
            direction [dict get $o -direction] \
            theme     [dict get $o -theme] \
            fontfile  [dict get $o -fontfile] \
            nodeGap 30 rankGap 70 padding 20] \
        nodes {} edges {}]
}

proc ::tclutils::tudiagram::setMeta {d args} {
    set m [dict get $d meta]
    foreach {k v} $args {
        set key [string trimleft $k -]
        if {$key eq "direction" && $v ni {LR TB RL BT}} { _err DIR "direction must be LR, TB, RL or BT" }
        dict set m $key $v
    }
    dict set d meta $m
    return $d
}

proc ::tclutils::tudiagram::addNode {d id args} {
    foreach n [dict get $d nodes] {
        if {[dict get $n id] eq $id} { _err DUPID "duplicate node id: $id" }
    }
    # -style is an optional per-node colour override: a dict with any of the
    # keys fill, stroke, text (e.g. -style {fill #e3f2fd stroke #1565c0}). Keys
    # that are absent fall back to the diagram theme. Anything that is not a
    # clean even-length list is ignored (theme is used), so an empty -style or a
    # legacy free-form value stays backward compatible.
    set o [::tclutils::common::parseOptions \
        {-label {} -shape box -style {}} {*}$args]
    set label [dict get $o -label]
    if {$label eq ""} { set label $id }
    if {[dict get $o -shape] ni {box rounded dot circle stadium diamond hexagon cylinder}} {
        _err ARG "shape must be box, rounded, dot, circle, stadium, diamond, hexagon or cylinder"
    }
    dict lappend d nodes [dict create \
        id $id label $label shape [dict get $o -shape] style [dict get $o -style]]
    return $d
}

proc ::tclutils::tudiagram::addEdge {d from to args} {
    # -style: solid (default), dashed, dotted or thick.
    # -arrow: end (default, head at the target), none, both or start.
    # -startMark / -endMark: cardinality end-marks at the from / to end --
    #   none (default), exactlyOne, zeroOrOne, oneOrMany, zeroOrMany.
    set o [::tclutils::common::parseOptions \
        {-label {} -style solid -arrow end -startMark none -endMark none} {*}$args]
    dict lappend d edges [dict create \
        from $from to $to label [dict get $o -label] \
        style [dict get $o -style] arrow [dict get $o -arrow] \
        startMark [dict get $o -startMark] endMark [dict get $o -endMark]]
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

# Approximate an ellipse outline as a polygon (the internal canvas exposes no
# circle/ellipse on the supersample proxy, only rect/line/polygon).
proc ::tclutils::tudiagram::_ellipsePts {cx cy rx ry {steps 24}} {
    set pts {}
    set tau 6.283185307179586
    for {set i 0} {$i < $steps} {incr i} {
        set a [expr {$tau * $i / $steps}]
        lappend pts [expr {int(round($cx + $rx*cos($a)))}] \
                    [expr {int(round($cy + $ry*sin($a)))}]
    }
    return $pts
}

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
    # RL/BT are laid out as their LR/TB mirror, then flipped at the end.
    set baseDir [expr {$dir in {LR RL} ? "LR" : "TB"}]
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
        switch -- [dict get $n shape] {
            dot {
                set W($id) [expr {6*$font + 8}]
                set H($id) [expr {6*$font + 8}]
            }
            circle {
                # square box whose diameter clears the label's diagonal
                set side [expr {int(ceil(hypot($tw,$thh))) + 2*$pad}]
                set W($id) $side; set H($id) $side
            }
            diamond {
                # the label sits in the inscribed rectangle of the rhombus
                set W($id) [expr {int($tw*1.5) + 2*$pad}]
                set H($id) [expr {int($thh*1.8) + 2*$pad}]
            }
            hexagon {
                # slanted ends add width
                set W($id) [expr {$tw + 2*$pad + $thh}]
            }
            cylinder {
                # top/bottom rims add height
                set H($id) [expr {$thh + 4*$pad}]
            }
        }
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
                set md [expr {$baseDir eq "LR" ? $W($id) : $H($id)}]
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
                if {$baseDir eq "LR"} {
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
                if {$baseDir eq "LR"} {
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

    # RL/BT: mirror the LR/TB layout on the relevant axis. Node x/y and edge
    # waypoints are flipped; arrowheads follow because the render derives them
    # from the (now mirrored) end segments.
    if {$dir eq "RL" || $dir eq "BT"} {
        set Wc [dict get $d meta width]
        set Hc [dict get $d meta height]
        set fn {}
        foreach n [dict get $d nodes] {
            if {$dir eq "RL"} {
                dict set n x [expr {$Wc - [dict get $n x] - [dict get $n width]}]
            } else {
                dict set n y [expr {$Hc - [dict get $n y] - [dict get $n height]}]
            }
            lappend fn $n
        }
        dict set d nodes $fn
        set fe {}
        foreach e [dict get $d edges] {
            set np {}
            foreach {px py} [dict get $e points] {
                if {$dir eq "RL"} {
                    lappend np [expr {$Wc - $px}] $py
                } else {
                    lappend np $px [expr {$Hc - $py}]
                }
            }
            dict set e points $np
            lappend fe $e
        }
        dict set d edges $fe
    }

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

# Draw one text line. With $gfont == "" this is the dependency-free 6x8 bitmap
# (the default). With a Glyphs font handle it renders real outlines via the
# tupngdraw fillcontours method, anamorphically fitted into the SAME 6x8 metric
# box (width = len*6*scale, height = 8*scale) so layout stays congruent with the
# SVG/bitmap path. Only reached on the raster backend (see render).
proc ::tclutils::tudiagram::_drawText {canvas gfont scale x y str color} {
    if {$gfont eq "" || $str eq ""} {
        $canvas text $x $y $str -scale $scale -color $color
        return
    }
    set cellH   [expr {8.0 * $scale}]
    set targetW [expr {[string length $str] * 6.0 * $scale}]
    set upm [$gfont get unitsPerEm]
    set asc [$gfont get ascender]
    set dsc [$gfont get descender]
    set span [expr {$asc - $dsc}]
    set adv 0.0
    foreach ch [split $str ""] {
        set adv [expr {$adv + [$gfont gget [$gfont unicode2glyphIndex $ch] advanceWidth]}]
    }
    if {$span <= 0 || $upm <= 0 || $adv <= 0} {
        $canvas text $x $y $str -scale $scale -color $color
        return
    }
    set sy [expr {$cellH / double($span)}]          ;# font units -> px (vertical)
    set sx [expr {$targetW / ($adv * $sy)}]         ;# squeeze to the metric width
    set baseline [expr {$y + $asc * $sy}]
    set pen 0.0
    foreach ch [split $str ""] {
        set gi [$gfont unicode2glyphIndex $ch]
        set aw [$gfont gget $gi advanceWidth]
        if {$gi != 0} {
            set g [$gfont glyph $gi]
            set contours {}
            foreach c [$g onUniformSteps 6 "at"] {
                set flat {}
                foreach pt $c {
                    lassign $pt fx fy
                    lappend flat \
                        [expr {$x + ($pen + $fx) * $sy * $sx}] \
                        [expr {$baseline - $fy * $sy}]
                }
                if {[llength $flat] >= 6} { lappend contours $flat }
            }
            if {[llength $contours]} {
                $canvas fillcontours $contours -color $color -rule nonzero
            }
            $g destroy
        }
        set pen [expr {$pen + $aw}]
    }
}

# Draw one segment as a dash/dot run (the canvas line has no native dash, so we
# emit short on/off pieces). on/off are lengths in 1x layout units.
proc ::tclutils::tudiagram::_segDash {canvas x1 y1 x2 y2 color width on off} {
    set dx [expr {$x2-$x1}]; set dy [expr {$y2-$y1}]
    set L [expr {hypot($dx,$dy)}]
    if {$L == 0} return
    set ux [expr {$dx/$L}]; set uy [expr {$dy/$L}]
    set pos 0.0; set draw 1
    while {$pos < $L} {
        set seg [expr {$draw ? $on : $off}]
        set end [expr {min($pos+$seg, $L)}]
        if {$draw} {
            $canvas line [expr {int($x1+$ux*$pos)}] [expr {int($y1+$uy*$pos)}] \
                         [expr {int($x1+$ux*$end)}] [expr {int($y1+$uy*$end)}] \
                         -color $color -width $width
        }
        set pos $end; set draw [expr {!$draw}]
    }
}

# Filled triangular arrowhead with the tip at (tx,ty), pointing away from (fx,fy).
proc ::tclutils::tudiagram::_drawArrowHead {canvas tx ty fx fy color} {
    set dx [expr {$tx-$fx}]; set dy [expr {$ty-$fy}]
    set L [expr {hypot($dx,$dy)}]
    if {$L == 0} return
    set ux [expr {$dx/$L}]; set uy [expr {$dy/$L}]
    set asz 9; set awd 5
    set bxp [expr {$tx-$asz*$ux}]; set byp [expr {$ty-$asz*$uy}]
    set px [expr {-$uy}]; set py [expr {$ux}]
    $canvas setfill $color
    $canvas polygon [list \
        [expr {int($tx)}] [expr {int($ty)}] \
        [expr {int($bxp+$awd*$px)}] [expr {int($byp+$awd*$py)}] \
        [expr {int($bxp-$awd*$px)}] [expr {int($byp-$awd*$py)}]] -fill 1 -outline 0
}

# --- cardinality end-marks (crow's foot) -------------------------------------
# All marks are measured from the node-edge point T=(tx,ty) back along -u (the
# unit vector F->T), so they sit in the existing edge gap. Drawn with line and
# polygon primitives only (the ring is a polygon), so SVG and raster stay
# congruent, exactly like the node shapes.

# A "bar" (a "one"): a segment perpendicular to the edge at offset d, half-width 6.
proc ::tclutils::tudiagram::_drawBar {canvas tx ty fx fy d color} {
    set dx [expr {$tx-$fx}]; set dy [expr {$ty-$fy}]
    set L [expr {hypot($dx,$dy)}]
    if {$L == 0} return
    set ux [expr {$dx/$L}]; set uy [expr {$dy/$L}]
    set px [expr {-$uy}];   set py [expr {$ux}]
    set w 6
    set cx [expr {$tx-$d*$ux}]; set cy [expr {$ty-$d*$uy}]
    $canvas line [expr {int($cx+$w*$px)}] [expr {int($cy+$w*$py)}] \
                 [expr {int($cx-$w*$px)}] [expr {int($cy-$w*$py)}] -width 2
}

# A "crow's foot" (a "many"): three lines fanning from an apex at offset 12 to
# the node-edge point T and to T +/- 7*p.
proc ::tclutils::tudiagram::_drawCrowFoot {canvas tx ty fx fy color} {
    set dx [expr {$tx-$fx}]; set dy [expr {$ty-$fy}]
    set L [expr {hypot($dx,$dy)}]
    if {$L == 0} return
    set ux [expr {$dx/$L}]; set uy [expr {$dy/$L}]
    set px [expr {-$uy}];   set py [expr {$ux}]
    set w 7
    set ax [expr {int($tx-12*$ux)}]; set ay [expr {int($ty-12*$uy)}]
    $canvas line $ax $ay [expr {int($tx)}]        [expr {int($ty)}]        -width 2
    $canvas line $ax $ay [expr {int($tx+$w*$px)}] [expr {int($ty+$w*$py)}] -width 2
    $canvas line $ax $ay [expr {int($tx-$w*$px)}] [expr {int($ty-$w*$py)}] -width 2
}

# A "ring" (a "zero"): an open 12-gon polygon of radius 4 centred at offset d.
proc ::tclutils::tudiagram::_drawRing {canvas tx ty fx fy d color} {
    set dx [expr {$tx-$fx}]; set dy [expr {$ty-$fy}]
    set L [expr {hypot($dx,$dy)}]
    if {$L == 0} return
    set ux [expr {$dx/$L}]; set uy [expr {$dy/$L}]
    set cx [expr {$tx-$d*$ux}]; set cy [expr {$ty-$d*$uy}]
    set r 4
    set pts {}
    for {set i 0} {$i < 12} {incr i} {
        set a [expr {$i*3.141592653589793/6.0}]
        lappend pts [expr {int($cx+$r*cos($a))}] [expr {int($cy+$r*sin($a))}]
    }
    $canvas setstroke $color
    $canvas polygon $pts -fill 0 -outline 1
}

# Dispatch: draw the composite end-mark. Unknown values draw nothing ("none").
proc ::tclutils::tudiagram::_drawEndMark {canvas tx ty fx fy mark color} {
    $canvas setstroke $color
    switch -- $mark {
        exactlyOne {
            _drawBar $canvas $tx $ty $fx $fy 7  $color
            _drawBar $canvas $tx $ty $fx $fy 13 $color
        }
        zeroOrOne {
            _drawBar  $canvas $tx $ty $fx $fy 7  $color
            _drawRing $canvas $tx $ty $fx $fy 16 $color
        }
        oneOrMany {
            _drawCrowFoot $canvas $tx $ty $fx $fy $color
            _drawBar      $canvas $tx $ty $fx $fy 16 $color
        }
        zeroOrMany {
            _drawCrowFoot $canvas $tx $ty $fx $fy $color
            _drawRing     $canvas $tx $ty $fx $fy 18 $color
        }
    }
}

proc ::tclutils::tudiagram::render {d canvas} {
    if {![dict exists $d meta laid]} { set d [layout $d] }
    set th [theme [dict get $d meta theme]]
    set fillC   [dict get $th fill]
    set strokeC [dict get $th stroke]
    set textC   [dict get $th text]
    set edgeC   [dict get $th edge]
    set font    [dict get $th font]

    # Optional real-font path: only on the raster (tupngdraw) backend, and only
    # if -fontfile was given. Needs the third-party Glyphs package (A. Buratti,
    # permissive licence; NOT bundled). A set-but-missing file is a hard error;
    # a missing Glyphs package degrades silently to the 6x8 bitmap (best effort).
    set fontfile [expr {[dict exists $d meta fontfile] ? [dict get $d meta fontfile] : ""}]
    set gfont ""
    if {$fontfile ne "" && "fillcontours" in [info object methods $canvas -all]} {
        if {![file exists $fontfile]} { _err FONT "font file not found: $fontfile" }
        if {![catch {package require Glyphs}]} {
            catch {set gfont [Glyphs::new $fontfile]}
        }
    }

    # edges first (under boxes): draw the precomputed polyline, then an arrowhead
    foreach e [dict get $d edges] {
        set pts [dict get $e points]
        if {[llength $pts] < 4} continue
        $canvas setstroke $edgeC
        $canvas setlinewidth 2
        set est [expr {[dict exists $e style] ? [dict get $e style] : "solid"}]
        for {set i 0} {$i < [llength $pts]-2} {incr i 2} {
            set x1 [expr {int([lindex $pts $i])}];   set y1 [expr {int([lindex $pts [expr {$i+1}]])}]
            set x2 [expr {int([lindex $pts [expr {$i+2}]])}]; set y2 [expr {int([lindex $pts [expr {$i+3}]])}]
            switch -- $est {
                dashed  { _segDash $canvas $x1 $y1 $x2 $y2 $edgeC 2 6 4 }
                dotted  { _segDash $canvas $x1 $y1 $x2 $y2 $edgeC 2 2 3 }
                thick   { $canvas line $x1 $y1 $x2 $y2 -width 4 }
                default { $canvas line $x1 $y1 $x2 $y2 -width 2 }
            }
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
            _drawText $canvas $gfont $ef $lx $ly $lbl $edgeC
        }
        # cardinality end-marks: drawn before the arrow block's "none" early-out,
        # so arrowless edges (e.g. ER relationships) still get their marks.
        set sm [expr {[dict exists $e startMark] ? [dict get $e startMark] : "none"}]
        set em [expr {[dict exists $e endMark]   ? [dict get $e endMark]   : "none"}]
        if {$em ne "none"} {
            _drawEndMark $canvas [lindex $pts end-1] [lindex $pts end] \
                [lindex $pts end-3] [lindex $pts end-2] $em $edgeC
        }
        if {$sm ne "none"} {
            _drawEndMark $canvas [lindex $pts 0] [lindex $pts 1] \
                [lindex $pts 2] [lindex $pts 3] $sm $edgeC
        }
        set ar [dict get $e arrow]
        if {$ar eq "none"} continue
        # head at the end (tip = last point) and/or at the start (tip = first)
        set ex [lindex $pts end-1]; set ey [lindex $pts end]
        set efx [lindex $pts end-3]; set efy [lindex $pts end-2]
        set sx [lindex $pts 0]; set sy [lindex $pts 1]
        set sfx [lindex $pts 2]; set sfy [lindex $pts 3]
        switch -- $ar {
            both {
                _drawArrowHead $canvas $ex $ey $efx $efy $edgeC
                _drawArrowHead $canvas $sx $sy $sfx $sfy $edgeC
            }
            start {
                _drawArrowHead $canvas $sx $sy $sfx $sfy $edgeC
            }
            default {
                # "end" and any other value: a single head; back-edges flip it
                if {[dict get $e arrowStart]} {
                    _drawArrowHead $canvas $sx $sy $sfx $sfy $edgeC
                } else {
                    _drawArrowHead $canvas $ex $ey $efx $efy $edgeC
                }
            }
        }
    }

    # boxes + labels
    foreach n [dict get $d nodes] {
        set x [dict get $n x]; set y [dict get $n y]
        set w [dict get $n width]; set h [dict get $n height]
        # per-node colour overrides from -style (fill/stroke/text), else theme
        set nf $fillC; set ns $strokeC; set nt $textC
        set nstyle [dict get $n style]
        if {[string is list $nstyle] && [llength $nstyle] % 2 == 0} {
            if {[dict exists $nstyle fill]}   { set nf [dict get $nstyle fill] }
            if {[dict exists $nstyle stroke]} { set ns [dict get $nstyle stroke] }
            if {[dict exists $nstyle text]}   { set nt [dict get $nstyle text] }
        }
        $canvas setfill $nf
        $canvas setstroke $ns
        $canvas setlinewidth 2
        set x2 [expr {$x+$w}]; set y2 [expr {$y+$h}]
        set cx [expr {int($x+$w/2.0)}]; set cy [expr {int($y+$h/2.0)}]
        switch -- [dict get $n shape] {
            dot {
                # state-diagram start/end marker: filled circle, no label
                $canvas rect $x $y $x2 $y2 -fill 1 -fillcolor $ns -outline 0 \
                    -rx [expr {$w/2}] -ry [expr {$h/2}]
            }
            rounded {
                $canvas rect $x $y $x2 $y2 -fill 1 -fillcolor $nf -outline 1 -color $ns \
                    -rx 8 -ry 8
            }
            stadium {
                $canvas rect $x $y $x2 $y2 -fill 1 -fillcolor $nf -outline 1 -color $ns \
                    -rx [expr {$h/2}] -ry [expr {$h/2}]
            }
            circle {
                $canvas rect $x $y $x2 $y2 -fill 1 -fillcolor $nf -outline 1 -color $ns \
                    -rx [expr {$w/2}] -ry [expr {$h/2}]
            }
            diamond {
                $canvas polygon [list $cx $y  $x2 $cy  $cx $y2  $x $cy] \
                    -fill 1 -fillcolor $nf -outline 1 -color $ns
            }
            hexagon {
                set s [expr {int(min($h*0.5, $w*0.3))}]
                $canvas polygon [list $x $cy  [expr {$x+$s}] $y  [expr {$x2-$s}] $y \
                    $x2 $cy  [expr {$x2-$s}] $y2  [expr {$x+$s}] $y2] \
                    -fill 1 -fillcolor $nf -outline 1 -color $ns
            }
            cylinder {
                set ry [expr {int(min($h*0.18, $w*0.4))}]
                if {$ry < 2} { set ry 2 }
                set rx [expr {int($w/2)}]
                set topY [expr {$y+$ry}]; set botY [expr {$y2-$ry}]
                $canvas polygon [_ellipsePts $cx $botY $rx $ry] \
                    -fill 1 -fillcolor $nf -outline 1 -color $ns
                $canvas rect $x $topY $x2 $botY -fill 1 -fillcolor $nf -outline 0
                $canvas line $x $topY $x $botY -color $ns -width 2
                $canvas line $x2 $topY $x2 $botY -color $ns -width 2
                $canvas polygon [_ellipsePts $cx $topY $rx $ry] \
                    -fill 1 -fillcolor $nf -outline 1 -color $ns
            }
            default {
                $canvas rect $x $y $x2 $y2 -fill 1 -fillcolor $nf -outline 1 -color $ns
            }
        }
        if {[dict get $n shape] ne "dot"} {
        set lines [split [dict get $n label] \n]
        set lh [expr {8*$font}]
        set ty [expr {int($y + ($h - [llength $lines]*$lh)/2)}]
        foreach ln $lines {
            set tw [$canvas textwidth $ln -scale $font]
            set tx [expr {int($x + ($w-$tw)/2)}]
            _drawText $canvas $gfont $font $tx $ty $ln $nt
            incr ty $lh
        }
        }
    }
    if {$gfont ne ""} { catch {$gfont destroy} }
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

# Scale proxy: wraps a tupngdraw canvas and multiplies every coordinate, line
# width, corner radius and text scale by K. render draws at 1x (unchanged), the
# proxy emits at Kx into a Kx-sized canvas -> a supersampled, sharp PNG with the
# identical layout. textwidth passes through (render's centring math stays 1x).
oo::class create ::tclutils::tudiagram::ScaleCanvas {
    variable I K
    constructor {inner factor} { set I $inner; set K $factor }
    method setfill      {args} { $I setfill   {*}$args }
    method setstroke    {args} { $I setstroke {*}$args }
    method setlinewidth {w}    { $I setlinewidth [expr {$w * $K}] }
    method textwidth    {str args} { return [$I textwidth $str {*}$args] }
    method data         {}     { return [$I data] }
    method line {x1 y1 x2 y2 args} {
        set a {}
        foreach {o v} $args { if {$o eq "-width"} { lappend a $o [expr {$v*$K}] } else { lappend a $o $v } }
        $I line [expr {$x1*$K}] [expr {$y1*$K}] [expr {$x2*$K}] [expr {$y2*$K}] {*}$a
    }
    method rect {x1 y1 x2 y2 args} {
        set a {}
        foreach {o v} $args { if {$o in {-rx -ry}} { lappend a $o [expr {$v*$K}] } else { lappend a $o $v } }
        $I rect [expr {$x1*$K}] [expr {$y1*$K}] [expr {$x2*$K}] [expr {$y2*$K}] {*}$a
    }
    method text {x y str args} {
        set a {}
        foreach {o v} $args { if {$o eq "-scale"} { lappend a $o [expr {$v*$K}] } else { lappend a $o $v } }
        $I text [expr {$x*$K}] [expr {$y*$K}] $str {*}$a
    }
    method polygon {coords args} {
        set sc {}
        foreach {x y} $coords { lappend sc [expr {$x*$K}] [expr {$y*$K}] }
        $I polygon $sc {*}$args
    }
    method fillcontours {contours args} {
        set sc {}
        foreach c $contours {
            set pc {}
            foreach {x y} $c { lappend pc [expr {$x*$K}] [expr {$y*$K}] }
            lappend sc $pc
        }
        $I fillcontours $sc {*}$args
    }
}

# Render to PNG bytes at an integer supersample factor (1 = native).
proc ::tclutils::tudiagram::_pngData {d scale} {
    if {![dict exists $d meta laid]} { set d [layout $d] }
    set w [dict get $d meta width]; set h [dict get $d meta height]
    package require tclutils::tupngdraw
    if {$scale <= 1} {
        set c [::tclutils::tupngdraw::new -width $w -height $h -background white]
        render $d $c
        set out [$c data]
        $c destroy
        return $out
    }
    set inner [::tclutils::tupngdraw::new \
        -width [expr {int(ceil($w*$scale))}] -height [expr {int(ceil($h*$scale))}] \
        -background white]
    set c [::tclutils::tudiagram::ScaleCanvas new $inner $scale]
    render $d $c
    set out [$inner data]
    $c destroy
    $inner destroy
    return $out
}

proc ::tclutils::tudiagram::_optScale {args} {
    set s 1
    foreach {k v} $args { if {$k eq "-scale"} { set s $v } }
    if {![string is integer -strict $s] || $s < 1} {
        _err ARG "-scale must be a positive integer"
    }
    return $s
}

proc ::tclutils::tudiagram::toSvg {d args} {
    lassign [_canvas $d svg] d c
    render $d $c
    return [$c data]
}
proc ::tclutils::tudiagram::toPng {d args} {
    return [_pngData $d [_optScale {*}$args]]
}
proc ::tclutils::tudiagram::writeSvg {d file args} {
    lassign [_canvas $d svg] d c
    render $d $c
    return [$c write $file]
}
proc ::tclutils::tudiagram::writePng {d file args} {
    set png [_pngData $d [_optScale {*}$args]]
    set fh [open $file wb]
    fconfigure $fh -translation binary
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tudiagram 0.3
