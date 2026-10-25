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
# Error codes: {TCLUTILS TULAYOUT <REASON>} with REASON one of PAPER, SCALE,
# GRID, OPTION, BLOCKS, BLOCKID, VALUE, LAYOUT, VIEWPORT.

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
    variable version 0.2
}

proc ::tclutils::tulayout::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TULAYOUT $reason] $msg
}

# Parse "-opt value ..." against a defaults dict; unknown options and an
# option without a value raise {TCLUTILS TULAYOUT OPTION}.
proc ::tclutils::tulayout::_opts {defaults argList} {
    set out $defaults
    set n [llength $argList]
    for {set i 0} {$i < $n} {incr i 2} {
        set k [lindex $argList $i]
        if {![dict exists $defaults $k]} {
            _err OPTION "unknown option \"$k\": must be\
                [join [dict keys $defaults] {, }]"
        }
        if {$i + 1 >= $n} {
            _err OPTION "option \"$k\" requires a value"
        }
        dict set out $k [lindex $argList [expr {$i + 1}]]
    }
    return $out
}

# Standard values for missing block keys.
proc ::tclutils::tulayout::_stdDefaults {} {
    return {x 0 y 0 w 40 h 8 show 1}
}

# Raise VALUE when one of x y w h in $b is present but not a number, or
# show is present but not a boolean. $where prefixes the message.
proc ::tclutils::tulayout::_checkRaw {where b} {
    foreach key {x y w h} {
        if {[dict exists $b $key]} {
            set v [dict get $b $key]
            if {![string is double -strict $v]} {
                _err VALUE "${where}bad $key '$v'"
            }
        }
    }
    if {[dict exists $b show] && ![string is boolean -strict [dict get $b show]]} {
        _err VALUE "${where}bad show '[dict get $b show]'"
    }
}

# Raise VALUE when a normalised block has a negative x, y, w or h.
proc ::tclutils::tulayout::_checkRange {id nb} {
    foreach key {x y w h} {
        if {![dict exists $nb $key]} continue
        if {[dict get $nb $key] < 0} {
            switch -- $key {
                w { _err VALUE "block '$id': width must be >= 0" }
                h { _err VALUE "block '$id': height must be >= 0" }
                default { _err VALUE "block '$id': $key must be >= 0" }
            }
        }
    }
}

proc ::tclutils::tulayout::_checkDict {what d} {
    if {[catch {dict size $d}]} {
        _err BLOCKS "$what must be a dict"
    }
}

proc ::tclutils::tulayout::defaultBlockKeys {} {
    return {x y w h show label lockedY}
}

proc ::tclutils::tulayout::pageSize {paper {orientation portrait}} {
    variable papers
    set key [string tolower $paper]
    if {[dict exists $papers $key]} {
        lassign [dict get $papers $key] w h
    } elseif {[llength $paper] == 2
              && [string is double -strict [lindex $paper 0]]
              && [string is double -strict [lindex $paper 1]]} {
        # Freies Format als {Breite Hoehe} in mm -- fuer Etiketten,
        # Bons und alles andere, was kein Normpapier ist.
        lassign $paper w h
    } elseif {[regexp {^([0-9.]+)[xX]([0-9.]+)$} $paper -> pw ph]
              && [string is double -strict $pw]
              && [string is double -strict $ph]} {
        # Gleiches als "54x56".
        set w $pw ; set h $ph
    } else {
        return -code error -errorcode {TCLUTILS TULAYOUT PAPER} \
            "unknown paper '$paper': must be a4, letter, a5,\
             {width height} or WxH in mm"
    }
    if {$w <= 0 || $h <= 0} {
        return -code error -errorcode {TCLUTILS TULAYOUT PAPER} \
            "paper dimensions must be positive, got ${w}x${h}"
    }
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
    set o [_opts {-grid 5.0} $args]
    set grid [dict get $o -grid]
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
    set o [_opts [list -defaults [_stdDefaults]] $args]
    set d [dict get $o -defaults]
    set out [dict create]
    foreach key {label x y w h show lockedY} {
        if {[dict exists $block $key]} {
            dict set out $key [dict get $block $key]
        } elseif {[dict exists $d $key]} {
            dict set out $key [dict get $d $key]
        }
    }
    _checkRaw "" $out
    foreach key {x y w h} {
        if {[dict exists $out $key]} {
            dict set out $key [expr {double([dict get $out $key])}]
        }
    }
    if {[dict exists $out show]} {
        dict set out show [expr {[dict get $out show] ? 1 : 0}]
    }
    return $out
}

proc ::tclutils::tulayout::validateBlocks {blocks} {
    if {![llength $blocks] || [catch {dict size $blocks}]} {
        _err BLOCKS "blocks must be a non-empty dict"
    }
    set out [dict create]
    dict for {id b} $blocks {
        if {$id eq ""} { _err BLOCKID "block id must not be empty" }
        _checkDict "block '$id'" $b
        _checkRaw "block '$id': " $b
        set nb [normalizeBlock $b]
        _checkRange $id $nb
        dict set out $id $nb
    }
    return $out
}

proc ::tclutils::tulayout::blockRect {block args} {
    array set o [_opts {-height ""} $args]
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
    set keys [dict get [_opts {-keys {x y w show}} $args] -keys]
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
    set merged [mergeBlocks [dict get $target blocks] \
        [dict get $preset blocks] {*}$args]
    set out $target
    dict set out blocks $merged
    return $out
}

# Normalise and check every block of $blocks; a key missing in a block comes
# from its definition, then from the standard values. Ids that only appear
# in $definitions are created from the definition alone. $blocks may be
# empty (everything comes from the definitions).
proc ::tclutils::tulayout::ensureBlocks {blocks definitions} {
    _checkDict blocks $blocks
    _checkDict definitions $definitions
    set out [dict create]
    dict for {id b} $blocks {
        if {$id eq ""} { _err BLOCKID "block id must not be empty" }
        _checkDict "block '$id'" $b
        _checkRaw "block '$id': " $b
        set def {}
        if {[dict exists $definitions $id]} {
            set def [dict get $definitions $id]
            _checkDict "definition '$id'" $def
            _checkRaw "definition '$id': " $def
        }
        set nb [normalizeBlock $b -defaults [dict merge [_stdDefaults] $def]]
        _checkRange $id $nb
        dict set out $id $nb
    }
    dict for {id def} $definitions {
        if {[dict exists $out $id]} continue
        if {$id eq ""} { _err BLOCKID "block id must not be empty" }
        _checkDict "definition '$id'" $def
        _checkRaw "definition '$id': " $def
        set nb [normalizeBlock $def -defaults {}]
        _checkRange $id $nb
        dict set out $id $nb
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
    set m [dict get [_opts {-marginPx 20} $args] -marginPx]
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

package provide tclutils::tulayout 0.2
