# tclutils::tulayout -- page layout helpers (mm coordinates, block dicts)
# Description: page layout helpers (mm coordinates, block dicts)
# Category: Graphics · raster/vector
#
# Pure Tcl engine for document block layouts: paper sizes, mm<->px conversion,
# grid snap, block normalisation/validation, and preset merging. No Tk dependency.
#
#   tulayout::pageSize a4 ?portrait|landscape?
#   tulayout::mmToPx $mm $scale
#   tulayout::pxToMm $px $scale
#   tulayout::snap $mm ?-grid 5?
#   tulayout::mergeBlocks $base $preset ?-keys {x y w show}?
#   tulayout::mergeLayout $target $preset ?-keys {x y w show}?
#   tulayout::isAutoY $block
#   tulayout::normalizeBlock $block ?-defaults dict?
#   tulayout::validateBlocks $blocks
#   tulayout::blockRect $block ?-height $h?
#   tulayout::fitScale $pageWmm $pageHmm $viewWpx $viewHpx ?-marginPx 20?
#
# Error codes: {TCLUTILS TULAYOUT <REASON>}.

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tulayout {
    namespace export pageSize mmToPx pxToMm snap mergeBlocks mergeLayout \
        isAutoY normalizeBlock validateBlocks blockRect fitScale \
        defaultBlockKeys ensureBlocks blockOrder
    variable papers [dict create \
        a4     {210 297} \
        letter {216 279} \
        a5     {148 210}]
    variable version 0.1
}

proc ::tclutils::tulayout::defaultBlockKeys {} {
    return {x y w h show label lockedY}
}

proc ::tclutils::tulayout::pageSize {paper {orientation portrait}} {
    variable papers
    set key [string tolower $paper]
    if {![dict exists $papers $key]} {
        return -code error -errorcode {TCLUTILS TULAYOUT PAPER} \
            "unknown paper '$paper': must be a4, letter or a5"
    }
    lassign [dict get $papers $key] w h
    if {[string tolower $orientation] eq "landscape"} {
        return [list $h $w]
    }
    return [list $w $h]
}

proc ::tclutils::tulayout::mmToPx {mm scale} {
    if {![string is double -strict $scale] || $scale <= 0} {
        return -code error -errorcode {TCLUTILS TULAYOUT SCALE} \
            "scale must be a positive number"
    }
    return [expr {double($mm) * double($scale)}]
}

proc ::tclutils::tulayout::pxToMm {px scale} {
    if {![string is double -strict $scale] || $scale <= 0} {
        return -code error -errorcode {TCLUTILS TULAYOUT SCALE} \
            "scale must be a positive number"
    }
    return [expr {double($px) / double($scale)}]
}

proc ::tclutils::tulayout::snap {mm args} {
    array set o [list -grid 5.0]
    array set o $args
    set grid $o(-grid)
    if {![string is double -strict $grid] || $grid <= 0} {
        return -code error -errorcode {TCLUTILS TULAYOUT GRID} \
            "grid must be a positive number"
    }
    return [expr {round(double($mm) / $grid) * $grid}]
}

proc ::tclutils::tulayout::isAutoY {block} {
    if {![llength $block]} { return 0 }
    if {[dict exists $block lockedY] && [dict get $block lockedY]} { return 1 }
    if {[dict exists $block y] && [dict get $block y] == 0} { return 1 }
    return 0
}

proc ::tclutils::tulayout::normalizeBlock {block args} {
    array set o [list -defaults {x 0 y 0 w 40 h 8 show 1}]
    array set o $args
    set d $o(-defaults)
    set out [dict create]
    foreach key {label x y w h show lockedY} {
        if {[dict exists $block $key]} {
            dict set out $key [dict get $block $key]
        } elseif {[dict exists $d $key]} {
            dict set out $key [dict get $d $key]
        }
    }
    foreach key {x y w h} {
        if {[dict exists $out $key]} {
            dict set out $key [expr {double([dict get $out $key])}]
        }
    }
    if {[dict exists $out show]} {
        dict set out show [expr {!![dict get $out show]}]
    }
    return $out
}

proc ::tclutils::tulayout::validateBlocks {blocks} {
    if {![llength $blocks] || ([llength $blocks] % 2) != 0} {
        return -code error -errorcode {TCLUTILS TULAYOUT BLOCKS} \
            "blocks must be a non-empty dict"
    }
    set out [dict create]
    dict for {id b} $blocks {
        if {$id eq ""} {
            return -code error -errorcode {TCLUTILS TULAYOUT BLOCKID} \
                "block id must not be empty"
        }
        set nb [normalizeBlock $b]
        foreach key {x y w h} {
            set v [dict get $nb $key]
            if {![string is double -strict $v]} {
                return -code error -errorcode {TCLUTILS TULAYOUT VALUE} \
                    "block '$id': bad $key '$v'"
            }
            if {$key eq "w" && $v < 0} {
                return -code error -errorcode {TCLUTILS TULAYOUT VALUE} \
                    "block '$id': width must be >= 0"
            }
            if {$key in {x y} && $v < 0} {
                return -code error -errorcode {TCLUTILS TULAYOUT VALUE} \
                    "block '$id': $key must be >= 0"
            }
        }
        dict set out $id $nb
    }
    return $out
}

proc ::tclutils::tulayout::blockRect {block args} {
    array set o [list -height ""]
    array set o $args
    set b [normalizeBlock $block]
    set x [dict get $b x]
    set y [dict get $b y]
    set w [dict get $b w]
    if {$o(-height) ne ""} {
        set h $o(-height)
    } elseif {[dict exists $b h]} {
        set h [dict get $b h]
    } else {
        set h 8.0
    }
    return [list $x $y [expr {$x + $w}] [expr {$y + $h}]]
}

proc ::tclutils::tulayout::mergeBlocks {base preset args} {
    array set o [list -keys {x y w show}]
    array set o $args
    set keys $o(-keys)
    set out $base
    dict for {id pb} $preset {
        if {![dict exists $out $id]} continue
        foreach key $keys {
            if {[dict exists $pb $key]} {
                dict set out $id $key [dict get $pb $key]
            }
        }
    }
    return $out
}

proc ::tclutils::tulayout::mergeLayout {target preset args} {
    if {![dict exists $target blocks]} {
        return -code error -errorcode {TCLUTILS TULAYOUT LAYOUT} \
            "target layout has no 'blocks' key"
    }
    if {![dict exists $preset blocks]} {
        return -code error -errorcode {TCLUTILS TULAYOUT LAYOUT} \
            "preset layout has no 'blocks' key"
    }
    set merged [mergeBlocks [dict get $target blocks] [dict get $preset blocks] {*}$args]
    set out $target
    dict set out blocks $merged
    return $out
}

proc ::tclutils::tulayout::ensureBlocks {blocks definitions} {
    set out [validateBlocks $blocks]
    dict for {id def} $definitions {
        if {![dict exists $out $id]} {
            dict set out $id [normalizeBlock $def -defaults $def]
        } else {
            dict set out $id [normalizeBlock [dict get $out $id] -defaults $def]
        }
    }
    return $out
}

proc ::tclutils::tulayout::blockOrder {blocks {definitions {}}} {
    if {[llength $definitions]} {
        set order {}
        dict for {id _} $definitions { lappend order $id }
        foreach id [dict keys $blocks] {
            if {$id ni $order} { lappend order $id }
        }
        return $order
    }
    return [lsort [dict keys $blocks]]
}

proc ::tclutils::tulayout::fitScale {pageWmm pageHmm viewWpx viewHpx args} {
    array set o [list -marginPx 20]
    array set o $args
    set m $o(-marginPx)
    set aw [expr {$viewWpx - 2 * $m}]
    set ah [expr {$viewHpx - 2 * $m}]
    if {$aw <= 0 || $ah <= 0} {
        return -code error -errorcode {TCLUTILS TULAYOUT VIEWPORT} \
            "viewport too small for margin $m"
    }
    set sx [expr {$aw / double($pageWmm)}]
    set sy [expr {$ah / double($pageHmm)}]
    return [expr {min($sx, $sy)}]
}

package provide tclutils::tulayout 0.1
