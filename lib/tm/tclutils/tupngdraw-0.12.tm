# tclutils::tupngdraw -- a tiny pure-Tcl 2D drawing layer that renders to a
# Description: a tiny pure-Tcl 2D drawing layer that renders to a PNG via tclutils::tupng.
# Category: Graphics · raster/vector
# PNG via tclutils::tupng. No Tk, no external packages (TclOO is Tcl core).
#
# 0.12 (2026-06-20): rect accepts -rx/-ry for rounded corners (tessellated into
#   the antialiased polygon path; -ry defaults to -rx). This mirrors tusvg's
#   rect, so rounded boxes are now part of the tusvg<->tupngdraw swap contract.
#
# A drawing surface is a TclOO object whose command is the handle, in the
# spirit of pdf4tcl (but a PNG is a single surface, so there are no pages):
#
#   package require tclutils::tupngdraw
#   set p [tupngdraw::new -width 320 -height 200 -background white]
#   $p setfill {255 0 0}            ;# colours: red | #ff0000 | FF0000 | {r g b} | {r g b a}
#   $p setstroke black
#   $p setlinewidth 2
#   $p rect   20 20 140 90  -fill 1
#   $p circle 230 110 50    -fill 1
#   $p line   0 0 319 199
#   $p polygon {160 20 200 80 120 80} -fill 1
#   $p write demo.png -compression 9
#   $p destroy
#
# Colours are composited source-over (straight alpha), so semi-transparent
# fills blend with what is underneath. The internal buffer is a flat list of
# bytes (R G B A per pixel) mutated in place with lset; on write it is packed
# once and handed to tupng::encodeRGBARaw.
#
# Version 0.4 scope: setpixel, line, rect, circle, ellipse, polygon, arc
# (outline + fill), text (embedded 6x8 bitmap font), stroke/fill colour, line
# width, source-over alpha compositing, and antialiased strokes. All outline
# strokes use a coverage buffer (max per pixel), so thick translucent strokes
# are alpha-correct -- overlaps and corners do not darken twice. Antialiasing
# is on by default; toggle per surface with setantialias or per call with -aa.
# line supports -caps round|butt|square; rect/polygon/arc support
# -join round|bevel|mitre. Circle/ellipse/polygon/pie fills are antialiased
# (supersampled), so this is a fully antialiased rasteriser. The embedded original 6x8
# font also carries the German umlauts/eszett (a o u A O U diaeresis, ss).
#
# The 6x8 bitmap font is an original hand-authored set (95 ASCII glyphs
# plus German umlauts/eszett), embedded as glyph data. MIT, like the rest.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tupng 0.2
package require TclOO

namespace eval ::tclutils {}
namespace eval ::tclutils::tupngdraw {
    namespace export new
    variable version 0.11
    variable colors {
        black {0 0 0 255}        white {255 255 255 255}
        red {255 0 0 255}        green {0 128 0 255}
        lime {0 255 0 255}       blue {0 0 255 255}
        yellow {255 255 0 255}   cyan {0 255 255 255}
        magenta {255 0 255 255}  gray {128 128 128 255}
        grey {128 128 128 255}   silver {192 192 192 255}
        orange {255 165 0 255}   transparent {0 0 0 0}
        none {0 0 0 0}
    }
}

# Normalise a colour to {r g b a}: a name, "#rrggbb", "RRGGBBAA", {r g b} or
# {r g b a}. Alpha defaults to 255.
proc ::tclutils::tupngdraw::_color {c} {
    variable colors
    set key [string tolower $c]
    if {[dict exists $colors $key]} { return [dict get $colors $key] }
    set n [llength $c]
    if {$n == 3 || $n == 4} {
        foreach v $c {
            if {![string is integer -strict $v] || $v < 0 || $v > 255} { _colorErr $c }
        }
        if {$n == 3} { return [list [lindex $c 0] [lindex $c 1] [lindex $c 2] 255] }
        return $c
    }
    if {$n == 1} {
        set h [string trimleft [lindex $c 0] #]
        set len [string length $h]
        if {($len == 6 || $len == 8) && [string is xdigit -strict $h]} {
            if {$len == 6} { scan $h "%2x%2x%2x" r g b; return [list $r $g $b 255] }
            scan $h "%2x%2x%2x%2x" r g b a; return [list $r $g $b $a]
        }
    }
    _colorErr $c
}
proc ::tclutils::tupngdraw::_colorErr {c} {
    return -code error -errorcode {TCLUTILS TUPNGDRAW COLOR} "invalid colour: $c"
}

# Tessellate a rounded rectangle into a convex polygon (flat {x y x y ...}).
# Four elliptical corner arcs of `k` segments each, traced clockwise; the
# straight edges fall out as the chords between successive corner endpoints.
# Used by `rect -rx/-ry` so rounded boxes reuse the antialiased polygon code.
proc ::tclutils::tupngdraw::_roundRectPoints {x1 y1 x2 y2 rx ry {k 8}} {
    set pts {}
    set d2r [expr {acos(-1) / 180.0}]
    foreach {cx cy a0 a1} [list \
            [expr {$x1 + $rx}] [expr {$y1 + $ry}] 180 270 \
            [expr {$x2 - $rx}] [expr {$y1 + $ry}] 270 360 \
            [expr {$x2 - $rx}] [expr {$y2 - $ry}]   0  90 \
            [expr {$x1 + $rx}] [expr {$y2 - $ry}]  90 180] {
        for {set i 0} {$i <= $k} {incr i} {
            set a [expr {($a0 + ($a1 - $a0) * $i / double($k)) * $d2r}]
            lappend pts [expr {$cx + $rx * cos($a)}] [expr {$cy + $ry * sin($a)}]
        }
    }
    return $pts
}

# Source-over compositing of {sr sg sb sa} onto {dr dg db da} -> {r g b a}.
proc ::tclutils::tupngdraw::_over {dr dg db da sr sg sb sa} {
    if {$sa >= 255} { return [list $sr $sg $sb 255] }
    if {$sa <= 0}   { return [list $dr $dg $db $da] }
    set saf [expr {$sa / 255.0}]
    set daf [expr {$da / 255.0}]
    set oaf [expr {$saf + $daf * (1.0 - $saf)}]
    if {$oaf <= 0.0} { return {0 0 0 0} }
    set k [expr {$daf * (1.0 - $saf)}]
    set r [expr {int(round(($sr * $saf + $dr * $k) / $oaf))}]
    set g [expr {int(round(($sg * $saf + $dg * $k) / $oaf))}]
    set b [expr {int(round(($sb * $saf + $db * $k) / $oaf))}]
    set a [expr {int(round($oaf * 255.0))}]
    return [list $r $g $b $a]
}


# 6x8 bitmap font data + accessor -----------------------------------------
namespace eval ::tclutils::tupngdraw {
    # 6x8 bitmap font, ASCII 32..126; original hand-authored set.
    # One glyph = 8 row bitmasks, bit5 = leftmost column.
    variable font6x8 {
        {0 0 0 0 0 0 0 0}
        {24 24 24 24 24 0 24 0}
        {20 20 0 0 0 0 0 0}
        {20 20 62 20 62 20 20 0}
        {8 30 40 28 10 60 8 0}
        {50 52 8 16 38 11 0 0}
        {24 36 40 16 42 36 26 0}
        {24 16 32 0 0 0 0 0}
        {8 16 32 32 32 16 8 0}
        {32 16 8 8 8 16 32 0}
        {0 42 28 62 28 42 0 0}
        {0 8 8 62 8 8 0 0}
        {0 0 0 0 0 24 16 32}
        {0 0 0 62 0 0 0 0}
        {0 0 0 0 0 24 24 0}
        {2 4 8 16 32 32 0 0}
        {28 34 38 42 50 34 28 0}
        {8 24 40 8 8 8 62 0}
        {28 34 2 12 16 32 62 0}
        {62 2 4 12 2 34 28 0}
        {4 12 20 36 62 4 4 0}
        {62 32 60 2 2 34 28 0}
        {12 16 32 60 34 34 28 0}
        {62 2 4 8 16 16 16 0}
        {28 34 34 28 34 34 28 0}
        {28 34 34 30 2 4 24 0}
        {0 24 24 0 24 24 0 0}
        {0 24 24 0 24 16 32 0}
        {4 8 16 32 16 8 4 0}
        {0 0 62 0 62 0 0 0}
        {32 16 8 4 8 16 32 0}
        {28 34 2 12 8 0 8 0}
        {28 34 46 42 46 32 28 0}
        {28 34 34 62 34 34 34 0}
        {60 34 34 60 34 34 60 0}
        {28 34 32 32 32 34 28 0}
        {56 36 34 34 34 36 56 0}
        {62 32 32 60 32 32 62 0}
        {62 32 32 60 32 32 32 0}
        {28 34 32 44 34 34 28 0}
        {34 34 34 62 34 34 34 0}
        {28 8 8 8 8 8 28 0}
        {14 4 4 4 36 36 24 0}
        {34 36 40 48 40 36 34 0}
        {32 32 32 32 32 32 62 0}
        {34 54 42 42 34 34 34 0}
        {34 50 42 42 38 34 34 0}
        {28 34 34 34 34 34 28 0}
        {60 34 34 60 32 32 32 0}
        {28 34 34 34 42 36 26 0}
        {60 34 34 60 40 36 34 0}
        {30 32 32 28 2 2 60 0}
        {62 8 8 8 8 8 8 0}
        {34 34 34 34 34 34 28 0}
        {34 34 34 34 34 20 8 0}
        {34 34 34 42 42 54 34 0}
        {34 34 20 8 20 34 34 0}
        {34 34 20 8 8 8 8 0}
        {62 2 4 8 16 32 62 0}
        {28 16 16 16 16 16 28 0}
        {32 16 8 4 2 2 0 0}
        {28 4 4 4 4 4 28 0}
        {8 20 34 0 0 0 0 0}
        {0 0 0 0 0 0 0 62}
        {16 8 4 0 0 0 0 0}
        {0 0 28 2 30 34 30 0}
        {32 32 60 34 34 34 60 0}
        {0 0 28 34 32 34 28 0}
        {2 2 30 34 34 34 30 0}
        {0 0 28 34 62 32 28 0}
        {12 18 16 56 16 16 16 0}
        {0 0 30 34 34 30 2 28}
        {32 32 60 34 34 34 34 0}
        {8 0 24 8 8 8 28 0}
        {4 0 12 4 4 36 24 0}
        {32 32 36 40 48 40 36 0}
        {24 8 8 8 8 8 28 0}
        {0 0 52 42 42 42 34 0}
        {0 0 60 34 34 34 34 0}
        {0 0 28 34 34 34 28 0}
        {0 0 60 34 34 60 32 32}
        {0 0 30 34 34 30 2 2}
        {0 0 44 50 32 32 32 0}
        {0 0 30 32 28 2 60 0}
        {16 16 56 16 16 18 12 0}
        {0 0 34 34 34 38 26 0}
        {0 0 34 34 34 20 8 0}
        {0 0 34 42 42 42 20 0}
        {0 0 34 20 8 20 34 0}
        {0 0 34 34 34 30 2 28}
        {0 0 62 4 8 16 62 0}
        {12 8 8 16 8 8 12 0}
        {8 8 8 8 8 8 8 0}
        {24 8 8 4 8 8 24 0}
        {0 0 17 42 34 0 0 0}
    }
}

# Extension glyphs beyond ASCII, keyed by Unicode code point. German set:
# a/o/u-diaeresis use two top dots (cols 1,4); capital A/O/U-diaeresis use
# corner dots (cols 0,5) so they never merge with the letter body; eszett is a
# long-s ligature. Original, in the same 6x8 cell as the base glyphs.
array set ::tclutils::tupngdraw::font6x8ext {
    228 {18 0 28 2 30 34 30 0}
    246 {18 0 28 34 34 34 28 0}
    252 {18 0 34 34 34 38 26 0}
    196 {33 28 34 34 62 34 34 34}
    214 {33 28 34 34 34 34 34 28}
    220 {33 34 34 34 34 34 34 28}
    223 {24 36 36 40 36 36 44 0}
}
proc ::tclutils::tupngdraw::_glyph {code} {
    variable font6x8
    variable font6x8ext
    if {$code >= 32 && $code <= 126} {
        return [lindex $font6x8 [expr {$code - 32}]]
    }
    if {[info exists font6x8ext($code)]} {
        return $font6x8ext($code)
    }
    return [lindex $font6x8 0]
}

oo::class create ::tclutils::tupngdraw::Image {
    variable width height buffer background fill stroke linewidth antialias

    constructor {args} {
        set o [::tclutils::common::parseOptions \
            {-width 100 -height 100 -background white} {*}$args]
        set width  [::tclutils::common::ensurePositiveInteger [dict get $o -width] width]
        set height [::tclutils::common::ensurePositiveInteger [dict get $o -height] height]
        set background [::tclutils::tupngdraw::_color [dict get $o -background]]
        set fill   {0 0 0 255}
        set stroke {0 0 0 255}
        set linewidth 1
        set antialias 1
        my clear
    }

    method width  {} { return $width }
    method height {} { return $height }
    method pixel {x y} {
        set x [expr {int(round($x))}]; set y [expr {int(round($y))}]
        if {$x < 0 || $y < 0 || $x >= $width || $y >= $height} {
            return -code error -errorcode {TCLUTILS TUPNGDRAW RANGE} \
                "pixel out of range: $x $y"
        }
        set i [expr {($y * $width + $x) * 4}]
        return [lrange $buffer $i [expr {$i + 3}]]
    }

    method setfill   {c} { set fill   [::tclutils::tupngdraw::_color $c]; return }
    method setstroke {c} { set stroke [::tclutils::tupngdraw::_color $c]; return }
    method setlinewidth {n} {
        set linewidth [::tclutils::common::ensurePositiveInteger $n -linewidth]
        return
    }
    method setantialias {b} {
        set antialias [::tclutils::common::ensureBoolean $b -antialias]
        return
    }

    method clear {{color {}}} {
        set col [expr {$color eq "" ? $background : [::tclutils::tupngdraw::_color $color]}]
        lassign $col r g b a
        set buffer [lrepeat [expr {$width * $height}] $r $g $b $a]
        return
    }

    # composite one pixel (clipped); col is {r g b a}
    method _put {x y col} {
        if {$x < 0 || $y < 0 || $x >= $width || $y >= $height} return
        lassign $col sr sg sb sa
        set i [expr {($y * $width + $x) * 4}]
        if {$sa >= 255} {
            lset buffer $i $sr
            lset buffer [expr {$i + 1}] $sg
            lset buffer [expr {$i + 2}] $sb
            lset buffer [expr {$i + 3}] 255
            return
        }
        if {$sa <= 0} return
        set dr [lindex $buffer $i]
        set dg [lindex $buffer [expr {$i + 1}]]
        set db [lindex $buffer [expr {$i + 2}]]
        set da [lindex $buffer [expr {$i + 3}]]
        lassign [::tclutils::tupngdraw::_over $dr $dg $db $da $sr $sg $sb $sa] r g b a
        lset buffer $i $r
        lset buffer [expr {$i + 1}] $g
        lset buffer [expr {$i + 2}] $b
        lset buffer [expr {$i + 3}] $a
        return
    }

    method _hspan {x1 x2 y col} {
        if {$x1 > $x2} { lassign [list $x2 $x1] x1 x2 }
        for {set x $x1} {$x <= $x2} {incr x} { my _put $x $y $col }
        return
    }

    # --- stroking: AA coverage path (alpha-correct) + crisp Bresenham path -
    # Accumulate per-pixel coverage (0..1) of a segment into array covName,
    # keeping the maximum so overlapping segments do not darken twice.
    method _covSeg {covName x1 y1 x2 y2 hw cap} {
        upvar 1 $covName cov
        set minx [expr {int(floor([tcl::mathfunc::min $x1 $x2] - $hw - 1))}]
        set maxx [expr {int(ceil ([tcl::mathfunc::max $x1 $x2] + $hw + 1))}]
        set miny [expr {int(floor([tcl::mathfunc::min $y1 $y2] - $hw - 1))}]
        set maxy [expr {int(ceil ([tcl::mathfunc::max $y1 $y2] + $hw + 1))}]
        if {$minx < 0} {set minx 0}; if {$miny < 0} {set miny 0}
        if {$maxx > $width - 1}  {set maxx [expr {$width - 1}]}
        if {$maxy > $height - 1} {set maxy [expr {$height - 1}]}
        set dx [expr {$x2 - $x1}]; set dy [expr {$y2 - $y1}]
        set len2 [expr {$dx * $dx + $dy * $dy}]
        for {set y $miny} {$y <= $maxy} {incr y} {
            for {set x $minx} {$x <= $maxx} {incr x} {
                if {$len2 == 0} {
                    set d [expr {hypot($x - $x1, $y - $y1)}]
                } else {
                    set t [expr {(($x - $x1) * $dx + ($y - $y1) * $dy) / double($len2)}]
                    if {$cap eq "butt"} {
                        if {$t < 0.0 || $t > 1.0} continue
                        set tc $t
                    } else {
                        set tc [expr {$t < 0.0 ? 0.0 : ($t > 1.0 ? 1.0 : $t)}]
                    }
                    set d [expr {hypot($x - ($x1 + $tc * $dx), $y - ($y1 + $tc * $dy))}]
                }
                set c [expr {$hw + 0.5 - $d}]
                if {$c <= 0.0} continue
                if {$c > 1.0} {set c 1.0}
                set k $x,$y
                if {![info exists cov($k)] || $c > $cov($k)} { set cov($k) $c }
            }
        }
        return
    }
    # composite a coverage map once with colour col (alpha scaled by coverage)
    method _covBlit {covName col} {
        upvar 1 $covName cov
        lassign $col r g b a
        foreach {k c} [array get cov] {
            set aa [expr {int(round($a * $c))}]
            if {$aa <= 0} continue
            lassign [split $k ,] x y
            my _put $x $y [list $r $g $b $aa]
        }
        return
    }
    # Add antialiased polygon coverage (max-merged) into array covName, using
    # ss sub-scanlines in Y and analytic horizontal overlap in X (even-odd).
    method _polyCovAdd {covName xs ys ss} {
        upvar 1 $covName cov
        set n [llength $xs]
        if {$n < 3} return
        set ymin [expr {int(floor([tcl::mathfunc::min {*}$ys]))}]
        set ymax [expr {int(ceil ([tcl::mathfunc::max {*}$ys]))}]
        if {$ymin < 0} {set ymin 0}
        if {$ymax > $height - 1} {set ymax [expr {$height - 1}]}
        set inv [expr {1.0 / $ss}]
        for {set y $ymin} {$y <= $ymax} {incr y} {
            array unset rc
            for {set sIdx 0} {$sIdx < $ss} {incr sIdx} {
                set yy [expr {$y + ($sIdx + 0.5) * $inv}]
                set xint {}
                for {set i 0} {$i < $n} {incr i} {
                    set j [expr {($i + 1) % $n}]
                    set yi [lindex $ys $i]; set yj [lindex $ys $j]
                    if {($yi <= $yy && $yy < $yj) || ($yj <= $yy && $yy < $yi)} {
                        set xi [lindex $xs $i]; set xj [lindex $xs $j]
                        lappend xint [expr {$xi + ($yy - $yi) / double($yj - $yi) * ($xj - $xi)}]
                    }
                }
                set xint [lsort -real $xint]
                set m [llength $xint]
                for {set k 0} {$k + 1 < $m} {incr k 2} {
                    set xa [lindex $xint $k]; set xb [lindex $xint [expr {$k + 1}]]
                    if {$xa < 0} {set xa 0.0}
                    if {$xb > $width} {set xb [expr {double($width)}]}
                    if {$xb <= $xa} continue
                    set p0 [expr {int(floor($xa))}]
                    set p1 [expr {int(ceil($xb)) - 1}]
                    for {set px $p0} {$px <= $p1} {incr px} {
                        set ov [expr {(min($xb, $px + 1.0) - max($xa, double($px))) * $inv}]
                        if {$ov > 0} {
                            if {[info exists rc($px)]} {
                                set rc($px) [expr {$rc($px) + $ov}]
                            } else { set rc($px) $ov }
                        }
                    }
                }
            }
            foreach {px c} [array get rc] {
                if {$c > 1.0} {set c 1.0}
                set key $px,$y
                if {![info exists cov($key)] || $c > $cov($key)} { set cov($key) $c }
            }
        }
        return
    }
    # crisp (non-AA) square-stamp Bresenham segment, honouring linewidth
    method _bres {x1 y1 x2 y2 col} {
        set dx [expr {abs($x2 - $x1)}]; set dy [expr {-abs($y2 - $y1)}]
        set sx [expr {$x1 < $x2 ? 1 : -1}]; set sy [expr {$y1 < $y2 ? 1 : -1}]
        set err [expr {$dx + $dy}]; set x $x1; set y $y1
        while {1} {
            my _stamp $x $y $col
            if {$x == $x2 && $y == $y2} break
            set e2 [expr {2 * $err}]
            if {$e2 >= $dy} { set err [expr {$err + $dy}]; set x [expr {$x + $sx}] }
            if {$e2 <= $dx} { set err [expr {$err + $dx}]; set y [expr {$y + $sy}] }
        }
        return
    }
    method _stamp {x y col} {
        if {$linewidth <= 1} { my _put $x $y $col; return }
        set h [expr {$linewidth / 2}]
        for {set dy [expr {-$h}]} {$dy <= $linewidth - 1 - $h} {incr dy} {
            for {set dx [expr {-$h}]} {$dx <= $linewidth - 1 - $h} {incr dx} {
                my _put [expr {$x + $dx}] [expr {$y + $dy}] $col
            }
        }
        return
    }
    # Stroke a path (list of {x1 y1 x2 y2} segments) once with colour col.
    # aa=1 -> antialiased, alpha-correct (combined coverage); aa=0 -> crisp.
    method _strokePath {segs col aa lw {cap round}} {
        if {$aa} {
            array set cov {}
            set hw [expr {$lw / 2.0}]
            foreach s $segs {
                lassign $s ax ay bx by
                my _covSeg cov $ax $ay $bx $by $hw $cap
            }
            my _covBlit cov $col
        } else {
            set saved $linewidth
            set linewidth [expr {int(round($lw))}]
            if {$linewidth < 1} {set linewidth 1}
            foreach s $segs {
                lassign $s ax ay bx by
                my _bres $ax $ay $bx $by $col
            }
            set linewidth $saved
        }
        return
    }
    # Stroke a polyline/closed polygon with join style round|bevel|mitre.
    # round (or non-AA) delegates to the segment path; bevel/mitre build the
    # stroke as a coverage union of butt segment-quads plus per-vertex join
    # fillers (both sides; the inner one harmlessly overlaps), composited once.
    method _strokePoly {pts closed col aa hw join cap} {
        set np [expr {[llength $pts] / 2}]
        if {$np < 2} return
        if {$join ni {round bevel mitre}} {
            return -code error -errorcode {TCLUTILS TUPNGDRAW JOIN} \
                "-join must be round|bevel|mitre"
        }
        if {!$aa || $join eq "round"} {
            set segs {}
            for {set i 0} {$i < $np - 1} {incr i} {
                lappend segs [list [lindex $pts [expr {2*$i}]] [lindex $pts [expr {2*$i+1}]] \
                                   [lindex $pts [expr {2*$i+2}]] [lindex $pts [expr {2*$i+3}]]]
            }
            if {$closed} {
                lappend segs [list [lindex $pts end-1] [lindex $pts end] \
                                   [lindex $pts 0] [lindex $pts 1]]
            }
            my _strokePath $segs $col $aa [expr {$hw * 2}] $cap
            return
        }
        set vx {}; set vy {}
        for {set i 0} {$i < $np} {incr i} {
            lappend vx [lindex $pts [expr {2*$i}]]; lappend vy [lindex $pts [expr {2*$i+1}]]
        }
        array set cov {}
        set nseg [expr {$closed ? $np : $np - 1}]
        for {set i 0} {$i < $nseg} {incr i} {
            set j [expr {($i + 1) % $np}]
            set ax [lindex $vx $i]; set ay [lindex $vy $i]
            set bx [lindex $vx $j]; set by [lindex $vy $j]
            set dx [expr {$bx - $ax}]; set dy [expr {$by - $ay}]
            set len [expr {hypot($dx, $dy)}]
            if {$len == 0} continue
            set nx [expr {-$dy / $len * $hw}]; set ny [expr {$dx / $len * $hw}]
            my _polyCovAdd cov \
                [list [expr {$ax+$nx}] [expr {$bx+$nx}] [expr {$bx-$nx}] [expr {$ax-$nx}]] \
                [list [expr {$ay+$ny}] [expr {$by+$ny}] [expr {$by-$ny}] [expr {$ay-$ny}]] 4
        }
        set vlo [expr {$closed ? 0 : 1}]
        set vhi [expr {$closed ? $np - 1 : $np - 2}]
        for {set i $vlo} {$i <= $vhi} {incr i} {
            set pidx [expr {($i - 1 + $np) % $np}]; set qidx [expr {($i + 1) % $np}]
            set v0x [lindex $vx $i]; set v0y [lindex $vy $i]
            set d1x [expr {$v0x - [lindex $vx $pidx]}]; set d1y [expr {$v0y - [lindex $vy $pidx]}]
            set d2x [expr {[lindex $vx $qidx] - $v0x}]; set d2y [expr {[lindex $vy $qidx] - $v0y}]
            set l1 [expr {hypot($d1x, $d1y)}]; set l2 [expr {hypot($d2x, $d2y)}]
            if {$l1 == 0 || $l2 == 0} continue
            set n1x [expr {-$d1y / $l1 * $hw}]; set n1y [expr {$d1x / $l1 * $hw}]
            set n2x [expr {-$d2y / $l2 * $hw}]; set n2y [expr {$d2x / $l2 * $hw}]
            foreach sgn {1 -1} {
                set a1x [expr {$v0x + $sgn * $n1x}]; set a1y [expr {$v0y + $sgn * $n1y}]
                set a2x [expr {$v0x + $sgn * $n2x}]; set a2y [expr {$v0y + $sgn * $n2y}]
                if {$join eq "mitre"} {
                    set cr [expr {$d1x * $d2y - $d1y * $d2x}]
                    if {abs($cr) >= 1.0e-6} {
                        set t [expr {(($a2x - $a1x) * $d2y - ($a2y - $a1y) * $d2x) / $cr}]
                        set mx [expr {$a1x + $t * $d1x}]; set my [expr {$a1y + $t * $d1y}]
                        if {hypot($mx - $v0x, $my - $v0y) <= 4.0 * $hw} {
                            my _polyCovAdd cov [list $v0x $a1x $mx $a2x] \
                                               [list $v0y $a1y $my $a2y] 4
                            continue
                        }
                    }
                }
                my _polyCovAdd cov [list $a1x $a2x $v0x] [list $a1y $a2y $v0y] 4
            }
        }
        my _covBlit cov $col
        return
    }
    # Add coverage of a horizontal span [xa,xb) (one sub-scanline, weight inv)
    # into row-accumulator rc, with analytic per-pixel overlap.
    method _spanCov {rcName xa xb inv} {
        upvar 1 $rcName rc
        if {$xa < 0} {set xa 0.0}
        if {$xb > $width} {set xb [expr {double($width)}]}
        if {$xb <= $xa} return
        set p0 [expr {int(floor($xa))}]
        set p1 [expr {int(ceil($xb)) - 1}]
        for {set px $p0} {$px <= $p1} {incr px} {
            set ov [expr {(min($xb, $px + 1.0) - max($xa, double($px))) * $inv}]
            if {$ov > 0} {
                if {[info exists rc($px)]} {set rc($px) [expr {$rc($px) + $ov}]}                 else {set rc($px) $ov}
            }
        }
    }
    # Antialiased coverage of a set of contours (each a flat {x0 y0 x1 y1 ...}),
    # filled by winding rule (nonzero|evenodd), max-merged into array covName.
    # ss sub-scanlines in Y, analytic overlap in X; holes handled by the rule.
    method _contoursCovAdd {covName contours rule ss} {
        upvar 1 $covName cov
        set ymin 1e30; set ymax -1e30
        foreach c $contours {
            foreach {x y} $c {
                if {$y < $ymin} {set ymin $y}
                if {$y > $ymax} {set ymax $y}
            }
        }
        if {$ymin > $ymax} return
        set y0 [expr {int(floor($ymin))}]; set y1 [expr {int(ceil($ymax))}]
        if {$y0 < 0} {set y0 0}
        if {$y1 > $height - 1} {set y1 [expr {$height - 1}]}
        set inv [expr {1.0 / $ss}]
        set nz [expr {$rule eq "nonzero"}]
        for {set y $y0} {$y <= $y1} {incr y} {
            array unset rc
            for {set sI 0} {$sI < $ss} {incr sI} {
                set yy [expr {$y + ($sI + 0.5) * $inv}]
                set xs {}
                foreach c $contours {
                    set n [expr {[llength $c] / 2}]
                    if {$n < 2} continue
                    for {set i 0} {$i < $n} {incr i} {
                        set j [expr {($i + 1) % $n}]
                        set ay [lindex $c [expr {2*$i+1}]]; set by [lindex $c [expr {2*$j+1}]]
                        if {($ay <= $yy && $yy < $by) || ($by <= $yy && $yy < $ay)} {
                            set ax [lindex $c [expr {2*$i}]]; set bx [lindex $c [expr {2*$j}]]
                            set xx [expr {$ax + ($yy-$ay)/double($by-$ay)*($bx-$ax)}]
                            if {$nz} {
                                lappend xs [list $xx [expr {$by > $ay ? 1 : -1}]]
                            } else {
                                lappend xs $xx
                            }
                        }
                    }
                }
                if {$nz} {
                    set xs [lsort -real -index 0 $xs]
                    set wind 0; set startx 0.0
                    foreach pr $xs {
                        lassign $pr xx dir
                        set prev $wind; incr wind $dir
                        if {$prev == 0 && $wind != 0} {
                            set startx $xx
                        } elseif {$prev != 0 && $wind == 0} {
                            my _spanCov rc $startx $xx $inv
                        }
                    }
                } else {
                    set xs [lsort -real $xs]
                    set m [llength $xs]
                    for {set k 0} {$k + 1 < $m} {incr k 2} {
                        my _spanCov rc [lindex $xs $k] [lindex $xs [expr {$k+1}]] $inv
                    }
                }
            }
            foreach {px c} [array get rc] {
                if {$c > 1.0} {set c 1.0}
                set key $px,$y
                if {![info exists cov($key)] || $c > $cov($key)} {set cov($key) $c}
            }
        }
    }
    # Crisp (non-AA) multi-contour fill by winding rule.
    method _contoursCrisp {contours rule col} {
        set ymin 1e30; set ymax -1e30
        foreach c $contours {
            foreach {x y} $c {
                if {$y < $ymin} {set ymin $y}
                if {$y > $ymax} {set ymax $y}
            }
        }
        if {$ymin > $ymax} return
        set y0 [expr {int(floor($ymin))}]; set y1 [expr {int(ceil($ymax))}]
        if {$y0 < 0} {set y0 0}
        if {$y1 > $height - 1} {set y1 [expr {$height - 1}]}
        set nz [expr {$rule eq "nonzero"}]
        for {set y $y0} {$y <= $y1} {incr y} {
            set yy [expr {$y + 0.5}]
            set xs {}
            foreach c $contours {
                set n [expr {[llength $c] / 2}]
                if {$n < 2} continue
                for {set i 0} {$i < $n} {incr i} {
                    set j [expr {($i + 1) % $n}]
                    set ay [lindex $c [expr {2*$i+1}]]; set by [lindex $c [expr {2*$j+1}]]
                    if {($ay <= $yy && $yy < $by) || ($by <= $yy && $yy < $ay)} {
                        set ax [lindex $c [expr {2*$i}]]; set bx [lindex $c [expr {2*$j}]]
                        set xx [expr {$ax + ($yy-$ay)/double($by-$ay)*($bx-$ax)}]
                        if {$nz} {lappend xs [list $xx [expr {$by > $ay ? 1 : -1}]]}                         else {lappend xs $xx}
                    }
                }
            }
            if {$nz} {
                set xs [lsort -real -index 0 $xs]
                set wind 0; set startx 0.0
                foreach pr $xs {
                    lassign $pr xx dir
                    set prev $wind; incr wind $dir
                    if {$prev == 0 && $wind != 0} {set startx $xx}                     elseif {$prev != 0 && $wind == 0} {
                        my _hspan [expr {int(ceil($startx))}] [expr {int(floor($xx))}] $y $col
                    }
                }
            } else {
                set xs [lsort -real $xs]
                set m [llength $xs]
                for {set k 0} {$k + 1 < $m} {incr k 2} {
                    my _hspan [expr {int(ceil([lindex $xs $k]))}]                               [expr {int(floor([lindex $xs [expr {$k+1}]]))}] $y $col
                }
            }
        }
    }
    # Public: fill a list of contours (each {x0 y0 x1 y1 ...}) as one shape.
    # Options: -color, -rule nonzero|evenodd (default nonzero), -aa.
    method fillcontours {contours args} {
        set o [::tclutils::common::parseOptions \
            {-color {} -rule nonzero -aa {}} {*}$args]
        set rule [dict get $o -rule]
        if {$rule ni {nonzero evenodd}} {
            return -code error -errorcode {TCLUTILS TUPNGDRAW RULE} \
                "-rule must be nonzero|evenodd"
        }
        set fc [expr {[dict get $o -color] eq "" ? $fill \
            : [::tclutils::tupngdraw::_color [dict get $o -color]]}]
        set clean {}
        foreach c $contours { if {[llength $c] >= 6} { lappend clean $c } }
        if {![llength $clean]} return
        if {[my _resolveAA $o]} {
            array set cov {}
            my _contoursCovAdd cov $clean $rule 4
            my _covBlit cov $fc
        } else {
            my _contoursCrisp $clean $rule $fc
        }
        return
    }
    method _resolveAA {o} {
        set v [dict get $o -aa]
        if {$v eq ""} { return $antialias }
        return [::tclutils::common::ensureBoolean $v -aa]
    }

    method setpixel {x y args} {
        set x [expr {int(round($x))}]; set y [expr {int(round($y))}]
        set o [::tclutils::common::parseOptions {-color {}} {*}$args]
        set col [expr {[dict get $o -color] eq "" ? $stroke \
            : [::tclutils::tupngdraw::_color [dict get $o -color]]}]
        my _put $x $y $col
        return
    }

    method line {x1 y1 x2 y2 args} {
        foreach v {x1 y1 x2 y2} { set $v [expr {int(round([set $v]))}] }
        set o [::tclutils::common::parseOptions \
            {-color {} -width {} -aa {} -caps round} {*}$args]
        set col [expr {[dict get $o -color] eq "" ? $stroke \
            : [::tclutils::tupngdraw::_color [dict get $o -color]]}]
        set lw [expr {[dict get $o -width] eq "" ? $linewidth \
            : [::tclutils::common::ensurePositiveInteger [dict get $o -width] -width]}]
        set cap [dict get $o -caps]
        if {$cap ni {round butt square}} {
            return -code error -errorcode {TCLUTILS TUPNGDRAW CAPS} \
                "-caps must be round|butt|square"
        }
        if {$cap eq "square"} {
            set ex [expr {$x2 - $x1}]; set ey [expr {$y2 - $y1}]
            set len [expr {hypot($ex, $ey)}]
            if {$len > 0} {
                set hw [expr {$lw / 2.0}]
                set ux [expr {$ex / $len}]; set uy [expr {$ey / $len}]
                set x1 [expr {int(round($x1 - $ux * $hw))}]
                set y1 [expr {int(round($y1 - $uy * $hw))}]
                set x2 [expr {int(round($x2 + $ux * $hw))}]
                set y2 [expr {int(round($y2 + $uy * $hw))}]
            }
            set cap butt
        }
        my _strokePath [list [list $x1 $y1 $x2 $y2]] $col [my _resolveAA $o] $lw $cap
        return
    }

    method rect {x1 y1 x2 y2 args} {
        foreach v {x1 y1 x2 y2} { set $v [expr {int(round([set $v]))}] }
        set o [::tclutils::common::parseOptions \
            {-fill 0 -outline 1 -color {} -fillcolor {} -aa {} -join round \
             -rx 0 -ry 0} {*}$args]
        ::tclutils::common::ensureBoolean [dict get $o -fill] -fill
        if {$x1 > $x2} { lassign [list $x2 $x1] x1 x2 }
        if {$y1 > $y2} { lassign [list $y2 $y1] y1 y2 }
        # Rounded corners: tessellate into a convex polygon and reuse the
        # (antialiased) polygon fill/stroke. -ry defaults to -rx. Radii are
        # clamped to half the extent. rx=ry=0 keeps the fast square path below.
        set rx [dict get $o -rx]
        set ry [expr {[dict get $o -ry] == 0 ? $rx : [dict get $o -ry]}]
        if {$rx > 0 || $ry > 0} {
            set rx [expr {min($rx, ($x2 - $x1) / 2.0)}]
            set ry [expr {min($ry, ($y2 - $y1) / 2.0)}]
            my polygon [::tclutils::tupngdraw::_roundRectPoints $x1 $y1 $x2 $y2 $rx $ry] \
                -fill    [dict get $o -fill]    -outline   [dict get $o -outline] \
                -color   [dict get $o -color]   -fillcolor [dict get $o -fillcolor] \
                -aa      [dict get $o -aa]       -join      [dict get $o -join]
            return
        }
        if {[dict get $o -fill]} {
            set fc [expr {[dict get $o -fillcolor] eq "" ? $fill \
                : [::tclutils::tupngdraw::_color [dict get $o -fillcolor]]}]
            for {set y $y1} {$y <= $y2} {incr y} { my _hspan $x1 $x2 $y $fc }
        }
        if {[dict get $o -outline]} {
            set sc [expr {[dict get $o -color] eq "" ? $stroke \
                : [::tclutils::tupngdraw::_color [dict get $o -color]]}]
            my _strokePoly [list $x1 $y1 $x2 $y1 $x2 $y2 $x1 $y2] 1 $sc \
                [my _resolveAA $o] [expr {$linewidth / 2.0}] [dict get $o -join] round
        }
        return
    }

    method circle {cx cy r args} {
        set cx [expr {int(round($cx))}]; set cy [expr {int(round($cy))}]
        set r [::tclutils::common::ensurePositiveInteger [expr {int(round($r))}] radius]
        set o [::tclutils::common::parseOptions \
            {-fill 0 -outline 1 -color {} -fillcolor {} -aa {} -join round} {*}$args]
        ::tclutils::common::ensureBoolean [dict get $o -fill] -fill
        if {[dict get $o -fill]} {
            set fc [expr {[dict get $o -fillcolor] eq "" ? $fill \
                : [::tclutils::tupngdraw::_color [dict get $o -fillcolor]]}]
            if {[my _resolveAA $o]} {
                lassign $fc fr fg fb fa
                set lo [expr {$cy - $r - 1}]; set hi [expr {$cy + $r + 1}]
                set lx [expr {$cx - $r - 1}]; set hx [expr {$cx + $r + 1}]
                for {set y $lo} {$y <= $hi} {incr y} {
                    for {set x $lx} {$x <= $hx} {incr x} {
                        set c [expr {$r + 0.5 - hypot($x - $cx, $y - $cy)}]
                        if {$c <= 0.0} continue
                        if {$c > 1.0} {set c 1.0}
                        my _put $x $y [list $fr $fg $fb [expr {int(round($fa * $c))}]]
                    }
                }
            } else {
                for {set dy [expr {-$r}]} {$dy <= $r} {incr dy} {
                    set dx [expr {int(floor(sqrt(double($r*$r - $dy*$dy))))}]
                    my _hspan [expr {$cx - $dx}] [expr {$cx + $dx}] [expr {$cy + $dy}] $fc
                }
            }
        }
        if {![dict get $o -outline]} { return }
        set sc [expr {[dict get $o -color] eq "" ? $stroke \
            : [::tclutils::tupngdraw::_color [dict get $o -color]]}]
        my _strokePath [my _ringSegs $cx $cy $r $r] $sc [my _resolveAA $o] $linewidth
        return
    }

    # sampled closed-ellipse/circle outline as a segment list
    method _ringSegs {cx cy rx ry} {
        set steps [expr {int(ceil(6.2831853 * (($rx > $ry) ? $rx : $ry)))}]
        if {$steps < 12} { set steps 12 }
        set pts {}
        for {set i 0} {$i <= $steps} {incr i} {
            set a [expr {6.2831853 * $i / $steps}]
            lappend pts [expr {$cx + $rx * cos($a)}] [expr {$cy + $ry * sin($a)}]
        }
        set segs {}
        set n [expr {[llength $pts] / 2}]
        for {set i 0} {$i < $n - 1} {incr i} {
            lappend segs [list [lindex $pts [expr {2*$i}]] [lindex $pts [expr {2*$i+1}]] \
                               [lindex $pts [expr {2*$i+2}]] [lindex $pts [expr {2*$i+3}]]]
        }
        return $segs
    }

    method ellipse {cx cy rx ry args} {
        set cx [expr {int(round($cx))}]; set cy [expr {int(round($cy))}]
        set rx [::tclutils::common::ensurePositiveInteger [expr {int(round($rx))}] rx]
        set ry [::tclutils::common::ensurePositiveInteger [expr {int(round($ry))}] ry]
        set o [::tclutils::common::parseOptions \
            {-fill 0 -outline 1 -color {} -fillcolor {} -aa {} -join round} {*}$args]
        ::tclutils::common::ensureBoolean [dict get $o -fill] -fill
        if {[dict get $o -fill]} {
            set fc [expr {[dict get $o -fillcolor] eq "" ? $fill \
                : [::tclutils::tupngdraw::_color [dict get $o -fillcolor]]}]
            if {[my _resolveAA $o]} {
                set steps [expr {int(ceil(6.2831853 * (($rx > $ry) ? $rx : $ry)))}]
                if {$steps < 24} {set steps 24}
                set exs {}; set eys {}
                for {set i 0} {$i < $steps} {incr i} {
                    set a [expr {6.2831853 * $i / $steps}]
                    lappend exs [expr {$cx + $rx * cos($a)}]
                    lappend eys [expr {$cy + $ry * sin($a)}]
                }
                array set ecov {}
                my _polyCovAdd ecov $exs $eys 4
                my _covBlit ecov $fc
            } else {
                for {set dy [expr {-$ry}]} {$dy <= $ry} {incr dy} {
                    set t [expr {1.0 - (double($dy) * $dy) / (double($ry) * $ry)}]
                    if {$t < 0.0} { set t 0.0 }
                    set dx [expr {int(floor($rx * sqrt($t)))}]
                    my _hspan [expr {$cx - $dx}] [expr {$cx + $dx}] [expr {$cy + $dy}] $fc
                }
            }
        }
        if {![dict get $o -outline]} { return }
        set sc [expr {[dict get $o -color] eq "" ? $stroke \
            : [::tclutils::tupngdraw::_color [dict get $o -color]]}]
        my _strokePath [my _ringSegs $cx $cy $rx $ry] $sc [my _resolveAA $o] $linewidth
        return
    }

    method polygon {points args} {
        set o [::tclutils::common::parseOptions \
            {-fill 0 -outline 1 -color {} -fillcolor {} -aa {} -join round} {*}$args]
        ::tclutils::common::ensureBoolean [dict get $o -fill] -fill
        set np [expr {[llength $points] / 2}]
        if {$np < 3} {
            return -code error -errorcode {TCLUTILS TUPNGDRAW POLY} \
                "polygon needs at least 3 points"
        }
        set xs {}; set ys {}
        foreach {x y} $points { lappend xs [expr {int(round($x))}]; lappend ys [expr {int(round($y))}] }
        if {[dict get $o -fill]} {
            set fc [expr {[dict get $o -fillcolor] eq "" ? $fill \
                : [::tclutils::tupngdraw::_color [dict get $o -fillcolor]]}]
            if {[my _resolveAA $o]} {
                array set pcov {}
                my _polyCovAdd pcov $xs $ys 4
                my _covBlit pcov $fc
            } else {
                set ymin [tcl::mathfunc::min {*}$ys]
                set ymax [tcl::mathfunc::max {*}$ys]
                for {set y $ymin} {$y <= $ymax} {incr y} {
                    set xint {}
                    for {set i 0} {$i < $np} {incr i} {
                        set j [expr {($i + 1) % $np}]
                        set yi [lindex $ys $i]; set yj [lindex $ys $j]
                        set xi [lindex $xs $i]; set xj [lindex $xs $j]
                        if {($yi <= $y && $y < $yj) || ($yj <= $y && $y < $yi)} {
                            lappend xint [expr {$xi + (double($y - $yi) / ($yj - $yi)) * ($xj - $xi)}]
                        }
                    }
                    set xint [lsort -real $xint]
                    set m [llength $xint]
                    for {set k 0} {$k + 1 < $m} {incr k 2} {
                        set xa [expr {int(ceil([lindex $xint $k]))}]
                        set xb [expr {int(floor([lindex $xint [expr {$k + 1}]]))}]
                        my _hspan $xa $xb $y $fc
                    }
                }
            }
        }
        if {![dict get $o -outline]} { return }
        set sc [expr {[dict get $o -color] eq "" ? $stroke \
            : [::tclutils::tupngdraw::_color [dict get $o -color]]}]
        set pp {}
        for {set i 0} {$i < $np} {incr i} { lappend pp [lindex $xs $i] [lindex $ys $i] }
        my _strokePoly $pp 1 $sc [my _resolveAA $o] [expr {$linewidth / 2.0}] \
            [dict get $o -join] round
        return
    }

    # angles in degrees; 0 = +x, increasing sweeps clockwise on screen (y down)
    method arc {cx cy r a0 a1 args} {
        set cx [expr {int(round($cx))}]; set cy [expr {int(round($cy))}]
        set r  [::tclutils::common::ensurePositiveInteger [expr {int(round($r))}] r]
        set o [::tclutils::common::parseOptions \
            {-color {} -width {} -fill 0 -fillcolor {} -style arc -aa {} -join round} {*}$args]
        ::tclutils::common::ensureBoolean [dict get $o -fill] -fill
        set style [dict get $o -style]
        if {$style ni {arc pie chord}} {
            return -code error -errorcode {TCLUTILS TUPNGDRAW STYLE} \
                "-style must be arc|pie|chord"
        }
        if {$a1 < $a0} { set a1 [expr {$a1 + 360}] }
        set steps [expr {int(ceil(($a1 - $a0) / 360.0 * 6.2831853 * $r))}]
        if {$steps < 2} { set steps 2 }
        set pts {}
        for {set i 0} {$i <= $steps} {incr i} {
            set a [expr {($a0 + ($a1 - $a0) * $i / double($steps)) * 0.01745329252}]
            lappend pts [expr {$cx + $r * cos($a)}] [expr {$cy + $r * sin($a)}]
        }
        if {[dict get $o -fill] && $style ne "arc"} {
            set fc [expr {[dict get $o -fillcolor] eq "" ? $fill \
                : [::tclutils::tupngdraw::_color [dict get $o -fillcolor]]}]
            set fpts $pts
            if {$style eq "pie"} { set fpts [linsert $pts 0 $cx $cy] }
            my polygon $fpts -fill 1 -outline 0 -fillcolor $fc
        }
        set sc [expr {[dict get $o -color] eq "" ? $stroke \
            : [::tclutils::tupngdraw::_color [dict get $o -color]]}]
        set lw [expr {[dict get $o -width] eq "" ? $linewidth \
            : [::tclutils::common::ensurePositiveInteger [dict get $o -width] -width]}]
        set jn [dict get $o -join]
        if {$style eq "pie"} {
            my _strokePoly [linsert $pts 0 $cx $cy] 1 $sc [my _resolveAA $o] \
                [expr {$lw / 2.0}] $jn round
        } elseif {$style eq "chord"} {
            my _strokePoly $pts 1 $sc [my _resolveAA $o] [expr {$lw / 2.0}] $jn round
        } else {
            my _strokePoly $pts 0 $sc [my _resolveAA $o] [expr {$lw / 2.0}] $jn round
        }
        return
    }

    # --- text (embedded 6x8 bitmap font) ----------------------------------
    method text {x y str args} {
        set o [::tclutils::common::parseOptions \
            {-color {} -scale 1 -spacing 0} {*}$args]
        set col [expr {[dict get $o -color] eq "" ? $stroke \
            : [::tclutils::tupngdraw::_color [dict get $o -color]]}]
        set sc [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]
        set sp [dict get $o -spacing]
        set x [expr {int(round($x))}]
        set y [expr {int(round($y))}]
        set cell [expr {(6 + $sp) * $sc}]
        set cx $x
        foreach ch [split $str ""] {
            set g [::tclutils::tupngdraw::_glyph [scan $ch %c]]
            for {set ry 0} {$ry < 8} {incr ry} {
                set bits [lindex $g $ry]
                for {set rx 0} {$rx < 6} {incr rx} {
                    if {($bits >> (5 - $rx)) & 1} {
                        set bx [expr {$cx + $rx * $sc}]
                        set by [expr {$y + $ry * $sc}]
                        if {$sc == 1} {
                            my _put $bx $by $col
                        } else {
                            for {set dy 0} {$dy < $sc} {incr dy} {
                                for {set dx 0} {$dx < $sc} {incr dx} {
                                    my _put [expr {$bx + $dx}] [expr {$by + $dy}] $col
                                }
                            }
                        }
                    }
                }
            }
            incr cx $cell
        }
        return
    }
    method textwidth {str args} {
        set o [::tclutils::common::parseOptions {-scale 1 -spacing 0} {*}$args]
        set sc [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]
        return [expr {[string length $str] * (6 + [dict get $o -spacing]) * $sc}]
    }

    # Composite a packed-RGBA block (sw*sh*4 bytes, as from tupng::decode) at
    # (px,py), nearest-neighbour scaled by -scale (default 1), alpha-over.
    method paste {px py rgba sw sh args} {
        set o [::tclutils::common::parseOptions {-scale 1} {*}$args]
        set sc [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]
        binary scan $rgba cu* src
        set px [expr {int($px)}]; set py [expr {int($py)}]
        set tw [expr {$sw * $sc}]; set th [expr {$sh * $sc}]
        for {set dy 0} {$dy < $th} {incr dy} {
            set ty [expr {$py + $dy}]
            if {$ty < 0 || $ty >= $height} continue
            set srb [expr {($dy / $sc) * $sw * 4}]
            set drb [expr {$ty * $width * 4}]
            for {set dx 0} {$dx < $tw} {incr dx} {
                set tx [expr {$px + $dx}]
                if {$tx < 0 || $tx >= $width} continue
                set si [expr {$srb + ($dx / $sc) * 4}]
                set sa [lindex $src [expr {$si + 3}]]
                if {$sa == 0} continue
                set di [expr {$drb + $tx * 4}]
                set sr [lindex $src $si]
                set sg [lindex $src [expr {$si + 1}]]
                set sb [lindex $src [expr {$si + 2}]]
                if {$sa >= 255} {
                    lset buffer $di $sr
                    lset buffer [expr {$di + 1}] $sg
                    lset buffer [expr {$di + 2}] $sb
                    lset buffer [expr {$di + 3}] 255
                } else {
                    set a [expr {$sa / 255.0}]
                    lset buffer $di           [expr {int($sr * $a + [lindex $buffer $di] * (1 - $a) + 0.5)}]
                    lset buffer [expr {$di+1}] [expr {int($sg * $a + [lindex $buffer [expr {$di+1}]] * (1 - $a) + 0.5)}]
                    lset buffer [expr {$di+2}] [expr {int($sb * $a + [lindex $buffer [expr {$di+2}]] * (1 - $a) + 0.5)}]
                    lset buffer [expr {$di+3}] 255
                }
            }
        }
        return
    }

    method data {args} {
        set packed [binary format c* $buffer]
        # Default to the cheap "up" PNG filter: this is a UI rasteriser (flat
        # colour fills), where "up" encodes ~10x faster than the size-seeking
        # "best" heuristic for near-identical size. Callers may pass -filter
        # best (or any other) to override.
        if {[lsearch -exact $args -filter] < 0} {
            set args [linsert $args 0 -filter up]
        }
        return [::tclutils::tupng::encodeRGBARaw $packed $width $height {*}$args]
    }
    method write {file args} {
        set fid [open $file w]
        fconfigure $fid -translation binary
        puts -nonewline $fid [my data {*}$args]
        close $fid
        return $file
    }
}

proc ::tclutils::tupngdraw::new {args} {
    return [::tclutils::tupngdraw::Image new {*}$args]
}

package provide tclutils::tupngdraw 0.12
