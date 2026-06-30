# tusvg-0.2.tm – SVG canvas, congruent with the tupngdraw object API.
# Description: SVG canvas, congruent with the tupngdraw object API.
# Category: Graphics · raster/vector
#
# Goal of 0.2: tusvg and tupngdraw become drop-in swappable behind one drawing
# loop. Both are TclOO canvases created via `<pkg> new -width W -height H`, with
# identical method names and signatures for the shared primitives (rect, line,
# polygon, circle, ellipse, text, textwidth, setfill/setstroke/setlinewidth,
# data, write). tusvg emits an SVG document; tupngdraw paints RGBA pixels.
#
# CRITICAL — shared text metric: `textwidth` returns EXACTLY the same value as
# tupngdraw (len * (6 + spacing) * scale), and `text` renders with
# textLength/lengthAdjust so the on-canvas width matches that metric regardless
# of the viewer's font. This makes box-sizing backend-independent (the contract
# tudiagram relies on).
#
# Geometry congruence: rect/line take TWO CORNERS (x1 y1 x2 y2), like tupngdraw.
# Paint congruence: tupngdraw-style state (setfill/setstroke/setlinewidth) plus
# the same per-call options (-fill 0|1, -outline 0|1, -color, -fillcolor).
#
# Beyond the shared core, tusvg keeps its vector superset (path, polyline,
# gradients, the icon library) as additional methods / legacy procs — these have
# no tupngdraw counterpart and are not part of the swap contract.
#
# Namespace: ::tclutils::tusvg   Package: tclutils::tusvg 0.2
# Errors:    {TCLUTILS TUSVG <REASON>}
# Tcl 8.6+/9.x, TclOO core. No Tk, no external packages.

package require Tcl 8.6-
package require TclOO
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tusvg {
    namespace export new
}

# --- colour: accept the same inputs as tupngdraw, emit an SVG/CSS colour ------
#   CSS name ("red", "steelblue") or #hex -> passed through
#   {r g b}      -> rgb(r,g,b)
#   {r g b a}    -> rgba(r,g,b, a/255)
proc ::tclutils::tusvg::_color {c} {
    set n [llength $c]
    if {$n == 3} {
        lassign $c r g b
        return "rgb($r,$g,$b)"
    }
    if {$n == 4} {
        lassign $c r g b a
        return "rgba($r,$g,$b,[format %.3f [expr {$a / 255.0}]])"
    }
    if {$n == 1} {
        return [lindex $c 0]   ;# CSS name or #hex
    }
    return -code error -errorcode {TCLUTILS TUSVG COLOR} "invalid colour: $c"
}

proc ::tclutils::tusvg::_esc {s} {
    return [string map {& &amp; < &lt; > &gt; \" &quot;} $s]
}

# ---------------------------------------------------------------------------
# The canvas object.
# ---------------------------------------------------------------------------
oo::class create ::tclutils::tusvg::Canvas {
    variable width height background fill stroke linewidth body defs

    constructor {args} {
        set o [::tclutils::common::parseOptions \
            {-width 100 -height 100 -background white} {*}$args]
        set width  [::tclutils::common::ensurePositiveInteger [dict get $o -width]  -width]
        set height [::tclutils::common::ensurePositiveInteger [dict get $o -height] -height]
        set background [dict get $o -background]
        set fill   black
        set stroke black
        set linewidth 1
        set body {}
        set defs {}
    }

    method width  {} { return $width }
    method height {} { return $height }

    # --- state (congruent with tupngdraw) ---------------------------------
    method setfill      {c} { set fill   [::tclutils::tusvg::_color $c]; return }
    method setstroke    {c} { set stroke [::tclutils::tusvg::_color $c]; return }
    method setlinewidth {n} {
        set linewidth [::tclutils::common::ensurePositiveInteger $n -linewidth]
        return
    }

    # Translate the tupngdraw-style {-fill -outline -color -fillcolor} options
    # (plus current state) into an SVG fill/stroke attribute string.
    method _paint {o} {
        set f none
        if {[dict get $o -fill]} {
            set f [expr {[dict get $o -fillcolor] eq "" ? $fill \
                : [::tclutils::tusvg::_color [dict get $o -fillcolor]]}]
        }
        set s none
        set sw ""
        if {[dict get $o -outline]} {
            set s [expr {[dict get $o -color] eq "" ? $stroke \
                : [::tclutils::tusvg::_color [dict get $o -color]]}]
            set sw " stroke-width=\"$linewidth\""
        }
        return "fill=\"$f\" stroke=\"$s\"$sw"
    }

    # --- shared primitives -------------------------------------------------
    method rect {x1 y1 x2 y2 args} {
        set o [::tclutils::common::parseOptions \
            {-fill 0 -outline 1 -color {} -fillcolor {} -rx 0 -ry 0} {*}$args]
        ::tclutils::common::ensureBoolean [dict get $o -fill]    -fill
        ::tclutils::common::ensureBoolean [dict get $o -outline] -outline
        if {$x1 > $x2} { lassign [list $x2 $x1] x1 x2 }
        if {$y1 > $y2} { lassign [list $y2 $y1] y1 y2 }
        set w [expr {$x2 - $x1}]
        set h [expr {$y2 - $y1}]
        set rxry ""
        if {[dict get $o -rx] > 0} { append rxry " rx=\"[dict get $o -rx]\"" }
        if {[dict get $o -ry] > 0} { append rxry " ry=\"[dict get $o -ry]\"" }
        lappend body "<rect x=\"$x1\" y=\"$y1\" width=\"$w\" height=\"$h\"$rxry [my _paint $o]/>"
        return
    }

    method line {x1 y1 x2 y2 args} {
        set o [::tclutils::common::parseOptions \
            {-color {} -width {} -caps round} {*}$args]
        set col [expr {[dict get $o -color] eq "" ? $stroke \
            : [::tclutils::tusvg::_color [dict get $o -color]]}]
        set lw [expr {[dict get $o -width] eq "" ? $linewidth \
            : [::tclutils::common::ensurePositiveInteger [dict get $o -width] -width]}]
        set cap [dict get $o -caps]
        if {$cap ni {round butt square}} {
            return -code error -errorcode {TCLUTILS TUSVG CAPS} \
                "-caps must be round|butt|square"
        }
        lappend body "<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\"\
 stroke=\"$col\" stroke-width=\"$lw\" stroke-linecap=\"$cap\"/>"
        return
    }

    method polygon {points args} {
        set o [::tclutils::common::parseOptions \
            {-fill 0 -outline 1 -color {} -fillcolor {}} {*}$args]
        ::tclutils::common::ensureBoolean [dict get $o -fill]    -fill
        ::tclutils::common::ensureBoolean [dict get $o -outline] -outline
        if {[expr {[llength $points] / 2}] < 3} {
            return -code error -errorcode {TCLUTILS TUSVG POLY} \
                "polygon needs at least 3 points"
        }
        lappend body "<polygon points=\"[my _points $points]\" [my _paint $o]/>"
        return
    }

    method polyline {points args} {
        set o [::tclutils::common::parseOptions {-color {} -width {}} {*}$args]
        set col [expr {[dict get $o -color] eq "" ? $stroke \
            : [::tclutils::tusvg::_color [dict get $o -color]]}]
        set lw [expr {[dict get $o -width] eq "" ? $linewidth : [dict get $o -width]}]
        lappend body "<polyline points=\"[my _points $points]\" fill=\"none\"\
 stroke=\"$col\" stroke-width=\"$lw\"/>"
        return
    }

    method circle {cx cy r args} {
        set o [::tclutils::common::parseOptions \
            {-fill 0 -outline 1 -color {} -fillcolor {}} {*}$args]
        ::tclutils::common::ensureBoolean [dict get $o -fill]    -fill
        ::tclutils::common::ensureBoolean [dict get $o -outline] -outline
        lappend body "<circle cx=\"$cx\" cy=\"$cy\" r=\"$r\" [my _paint $o]/>"
        return
    }

    method ellipse {cx cy rx ry args} {
        set o [::tclutils::common::parseOptions \
            {-fill 0 -outline 1 -color {} -fillcolor {}} {*}$args]
        ::tclutils::common::ensureBoolean [dict get $o -fill]    -fill
        ::tclutils::common::ensureBoolean [dict get $o -outline] -outline
        lappend body "<ellipse cx=\"$cx\" cy=\"$cy\" rx=\"$rx\" ry=\"$ry\" [my _paint $o]/>"
        return
    }

    # Text metric IDENTICAL to tupngdraw; textLength forces the rendered width
    # to that metric so box-sizing is backend-independent.
    method textwidth {str args} {
        set o [::tclutils::common::parseOptions {-scale 1 -spacing 0} {*}$args]
        set sc [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]
        return [expr {[string length $str] * (6 + [dict get $o -spacing]) * $sc}]
    }

    method text {x y str args} {
        set o [::tclutils::common::parseOptions \
            {-color {} -scale 1 -spacing 0 -anchor start} {*}$args]
        set col [expr {[dict get $o -color] eq "" ? $stroke \
            : [::tclutils::tusvg::_color [dict get $o -color]]}]
        set sc [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]
        set tw [my textwidth $str -scale $sc -spacing [dict get $o -spacing]]
        set fs       [expr {8 * $sc}]
        set baseline [expr {$y + 7 * $sc}]
        set anchor [dict get $o -anchor]
        if {$anchor ni {start middle end}} {
            return -code error -errorcode {TCLUTILS TUSVG ANCHOR} \
                "-anchor must be start|middle|end"
        }
        # Anchor point x: start=left edge, middle=centre, end=right edge of the
        # metric box, so callers that centre via textwidth match tupngdraw.
        set ax [expr {$anchor eq "start" ? $x : ($anchor eq "end" ? $x + $tw : $x + $tw / 2.0)}]
        lappend body "<text x=\"$ax\" y=\"$baseline\" font-family=\"monospace\"\
 font-size=\"$fs\" textLength=\"$tw\" lengthAdjust=\"spacingAndGlyphs\"\
 text-anchor=\"$anchor\" fill=\"$col\">[::tclutils::tusvg::_esc $str]</text>"
        return
    }

    # --- SVG-only extensions (no tupngdraw counterpart) -------------------
    method path {d args} {
        set o [::tclutils::common::parseOptions \
            {-fill 0 -outline 1 -color {} -fillcolor {}} {*}$args]
        ::tclutils::common::ensureBoolean [dict get $o -fill]    -fill
        ::tclutils::common::ensureBoolean [dict get $o -outline] -outline
        lappend body "<path d=\"$d\" [my _paint $o]/>"
        return
    }

    # Embed a named icon from the legacy icon library at (x,y) scaled to `size`.
    method icon {name x y size args} {
        set inner [::tclutils::tusvg::icon $name $size {*}$args]
        # icon() returns a standalone <svg ...>...</svg>; nest it positioned.
        regsub {^<svg[^>]*>} $inner "<svg x=\"$x\" y=\"$y\" width=\"$size\"\
 height=\"$size\" viewBox=\"0 0 24 24\">" inner
        lappend body $inner
        return
    }

    method addDef {def} { lappend defs $def; return }

    # --- output ------------------------------------------------------------
    method data {args} {
        set bg ""
        if {$background ne "" && $background ne "none"} {
            set bg "  <rect x=\"0\" y=\"0\" width=\"$width\" height=\"$height\"\
 fill=\"[::tclutils::tusvg::_color $background]\"/>\n"
        }
        set d ""
        if {[llength $defs]} {
            set d "  <defs>\n    [join $defs "\n    "]\n  </defs>\n"
        }
        set elems ""
        foreach e $body { append elems "  $e\n" }
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$width\"\
 height=\"$height\" viewBox=\"0 0 $width $height\">\n$d$bg$elems</svg>\n"
    }

    method write {file args} {
        set fid [open $file w]
        fconfigure $fid -encoding utf-8
        puts -nonewline $fid [my data {*}$args]
        close $fid
        return $file
    }

    method _points {points} {
        set out {}
        foreach {x y} $points { lappend out "$x,$y" }
        return [join $out " "]
    }
}

proc ::tclutils::tusvg::new {args} {
    return [::tclutils::tusvg::Canvas new {*}$args]
}

# ===========================================================================
# LEGACY vector-authoring + icon library (tusvg 0.2 proc API).
# Not part of the tupngdraw swap contract; kept as the vector superset
# (gradients, paths, the 40+ icon set). The Canvas `icon` method delegates here.
# ===========================================================================
proc ::tclutils::tusvg::create {width height args} {
    array set opts {
        -viewBox ""
        -xmlns "http://www.w3.org/2000/svg"
        -id ""
    }
    array set opts $args
    
    set svg [dict create \
        type svg \
        width $width \
        height $height \
        viewBox $opts(-viewBox) \
        xmlns $opts(-xmlns) \
        id $opts(-id) \
        children {} \
        defs {} \
    ]
    
    return $svg
}

# ============================================================
# Elemente hinzufuegen
# ============================================================

proc ::tclutils::tusvg::rect {svgVar x y width height args} {
    upvar 1 $svgVar svg
    
    array set opts {
        -fill "#000000"
        -stroke "none"
        -strokeWidth 1
        -rx 0
        -ry 0
        -opacity 1
        -id ""
        -class ""
    }
    array set opts $args
    
    set elem [dict create \
        type rect \
        x $x y $y \
        width $width height $height \
        fill $opts(-fill) \
        stroke $opts(-stroke) \
        strokeWidth $opts(-strokeWidth) \
        rx $opts(-rx) ry $opts(-ry) \
        opacity $opts(-opacity) \
        id $opts(-id) \
        class $opts(-class) \
    ]
    
    dict lappend svg children $elem
}

proc ::tclutils::tusvg::circle {svgVar cx cy r args} {
    upvar 1 $svgVar svg
    
    array set opts {
        -fill "#000000"
        -stroke "none"
        -strokeWidth 1
        -opacity 1
        -id ""
    }
    array set opts $args
    
    set elem [dict create \
        type circle \
        cx $cx cy $cy r $r \
        fill $opts(-fill) \
        stroke $opts(-stroke) \
        strokeWidth $opts(-strokeWidth) \
        opacity $opts(-opacity) \
        id $opts(-id) \
    ]
    
    dict lappend svg children $elem
}

proc ::tclutils::tusvg::ellipse {svgVar cx cy rx ry args} {
    upvar 1 $svgVar svg
    
    array set opts {
        -fill "#000000"
        -stroke "none"
        -strokeWidth 1
        -opacity 1
        -id ""
    }
    array set opts $args
    
    set elem [dict create \
        type ellipse \
        cx $cx cy $cy rx $rx ry $ry \
        fill $opts(-fill) \
        stroke $opts(-stroke) \
        strokeWidth $opts(-strokeWidth) \
        opacity $opts(-opacity) \
        id $opts(-id) \
    ]
    
    dict lappend svg children $elem
}

proc ::tclutils::tusvg::line {svgVar x1 y1 x2 y2 args} {
    upvar 1 $svgVar svg
    
    array set opts {
        -stroke "#000000"
        -strokeWidth 1
        -strokeLinecap "butt"
        -opacity 1
        -id ""
    }
    array set opts $args
    
    set elem [dict create \
        type line \
        x1 $x1 y1 $y1 x2 $x2 y2 $y2 \
        stroke $opts(-stroke) \
        strokeWidth $opts(-strokeWidth) \
        strokeLinecap $opts(-strokeLinecap) \
        opacity $opts(-opacity) \
        id $opts(-id) \
    ]
    
    dict lappend svg children $elem
}

proc ::tclutils::tusvg::polyline {svgVar points args} {
    upvar 1 $svgVar svg
    
    array set opts {
        -fill "none"
        -stroke "#000000"
        -strokeWidth 1
        -strokeLinejoin "miter"
        -strokeLinecap "butt"
        -opacity 1
        -id ""
    }
    array set opts $args
    
    set elem [dict create \
        type polyline \
        points $points \
        fill $opts(-fill) \
        stroke $opts(-stroke) \
        strokeWidth $opts(-strokeWidth) \
        strokeLinejoin $opts(-strokeLinejoin) \
        strokeLinecap $opts(-strokeLinecap) \
        opacity $opts(-opacity) \
        id $opts(-id) \
    ]
    
    dict lappend svg children $elem
}

proc ::tclutils::tusvg::polygon {svgVar points args} {
    upvar 1 $svgVar svg
    
    array set opts {
        -fill "#000000"
        -stroke "none"
        -strokeWidth 1
        -opacity 1
        -id ""
    }
    array set opts $args
    
    set elem [dict create \
        type polygon \
        points $points \
        fill $opts(-fill) \
        stroke $opts(-stroke) \
        strokeWidth $opts(-strokeWidth) \
        opacity $opts(-opacity) \
        id $opts(-id) \
    ]
    
    dict lappend svg children $elem
}

proc ::tclutils::tusvg::path {svgVar d args} {
    upvar 1 $svgVar svg
    
    array set opts {
        -fill "none"
        -stroke "#000000"
        -strokeWidth 1
        -strokeLinejoin "miter"
        -strokeLinecap "butt"
        -opacity 1
        -id ""
    }
    array set opts $args
    
    set elem [dict create \
        type path \
        d $d \
        fill $opts(-fill) \
        stroke $opts(-stroke) \
        strokeWidth $opts(-strokeWidth) \
        strokeLinejoin $opts(-strokeLinejoin) \
        strokeLinecap $opts(-strokeLinecap) \
        opacity $opts(-opacity) \
        id $opts(-id) \
    ]
    
    dict lappend svg children $elem
}

proc ::tclutils::tusvg::textElement {svgVar x y content args} {
    # ACHTUNG: tksvg/svgnano (Tk 8.6) unterstuetzt KEINE <text> Elemente!
    # Text wird nur in Tk 9.0+ oder echten SVG-Viewern angezeigt.
    # Workaround: Text in InkScape zu Pfaden konvertieren (Shift+Ctrl+C)
    #
    upvar 1 $svgVar svg
    
    array set opts {
        -fill "#000000"
        -fontSize 12
        -fontFamily "sans-serif"
        -fontWeight "normal"
        -textAnchor "start"
        -dominantBaseline "auto"
        -opacity 1
        -id ""
    }
    array set opts $args
    
    set elem [dict create \
        type text \
        x $x y $y \
        content $content \
        fill $opts(-fill) \
        fontSize $opts(-fontSize) \
        fontFamily $opts(-fontFamily) \
        fontWeight $opts(-fontWeight) \
        textAnchor $opts(-textAnchor) \
        dominantBaseline $opts(-dominantBaseline) \
        opacity $opts(-opacity) \
        id $opts(-id) \
    ]
    
    dict lappend svg children $elem
}

# ============================================================
# Gradienten (in defs)
# ============================================================

proc ::tclutils::tusvg::linearGradient {svgVar id x1 y1 x2 y2 stops} {
    upvar 1 $svgVar svg
    
    set grad [dict create \
        type linearGradient \
        id $id \
        x1 $x1 y1 $y1 x2 $x2 y2 $y2 \
        stops $stops \
    ]
    
    dict lappend svg defs $grad
    return "url(#$id)"
}

proc ::tclutils::tusvg::radialGradient {svgVar id cx cy r stops} {
    upvar 1 $svgVar svg
    
    set grad [dict create \
        type radialGradient \
        id $id \
        cx $cx cy $cy r $r \
        stops $stops \
    ]
    
    dict lappend svg defs $grad
    return "url(#$id)"
}

# ============================================================
# Gruppen
# ============================================================

proc ::tclutils::tusvg::group {svgVar args} {
    upvar 1 $svgVar svg
    
    array set opts {
        -transform ""
        -opacity 1
        -id ""
    }
    array set opts $args
    
    # Eine neue Gruppe beginnen
    set groupSvg [dict create \
        type g \
        transform $opts(-transform) \
        opacity $opts(-opacity) \
        id $opts(-id) \
        children {} \
    ]
    
    return $groupSvg
}

proc ::tclutils::tusvg::addToGroup {groupVar element} {
    upvar 1 $groupVar group
    dict lappend group children $element
}

proc ::tclutils::tusvg::addGroup {svgVar group} {
    upvar 1 $svgVar svg
    dict lappend svg children $group
}

# ============================================================
# In String konvertieren
# ============================================================

proc ::tclutils::tusvg::_escape {text} {
    string map {& &amp; < &lt; > &gt; \" &quot; ' &apos;} $text
}

proc ::tclutils::tusvg::_renderElement {elem indent} {
    set type [dict get $elem type]
    set ind [string repeat "  " $indent]
    set out ""
    
    switch $type {
        rect {
            append out "$ind<rect"
            append out " x=\"[dict get $elem x]\""
            append out " y=\"[dict get $elem y]\""
            append out " width=\"[dict get $elem width]\""
            append out " height=\"[dict get $elem height]\""
            if {[dict get $elem rx] > 0} {
                append out " rx=\"[dict get $elem rx]\""
            }
            if {[dict get $elem ry] > 0} {
                append out " ry=\"[dict get $elem ry]\""
            }
            append out " fill=\"[dict get $elem fill]\""
            if {[dict get $elem stroke] ne "none"} {
                append out " stroke=\"[dict get $elem stroke]\""
                append out " stroke-width=\"[dict get $elem strokeWidth]\""
            }
            if {[dict get $elem opacity] < 1} {
                append out " opacity=\"[dict get $elem opacity]\""
            }
            if {[dict get $elem id] ne ""} {
                append out " id=\"[dict get $elem id]\""
            }
            append out "/>\n"
        }
        
        circle {
            append out "$ind<circle"
            append out " cx=\"[dict get $elem cx]\""
            append out " cy=\"[dict get $elem cy]\""
            append out " r=\"[dict get $elem r]\""
            append out " fill=\"[dict get $elem fill]\""
            if {[dict get $elem stroke] ne "none"} {
                append out " stroke=\"[dict get $elem stroke]\""
                append out " stroke-width=\"[dict get $elem strokeWidth]\""
            }
            if {[dict get $elem id] ne ""} {
                append out " id=\"[dict get $elem id]\""
            }
            append out "/>\n"
        }
        
        ellipse {
            append out "$ind<ellipse"
            append out " cx=\"[dict get $elem cx]\""
            append out " cy=\"[dict get $elem cy]\""
            append out " rx=\"[dict get $elem rx]\""
            append out " ry=\"[dict get $elem ry]\""
            append out " fill=\"[dict get $elem fill]\""
            if {[dict get $elem stroke] ne "none"} {
                append out " stroke=\"[dict get $elem stroke]\""
                append out " stroke-width=\"[dict get $elem strokeWidth]\""
            }
            append out "/>\n"
        }
        
        line {
            append out "$ind<line"
            append out " x1=\"[dict get $elem x1]\""
            append out " y1=\"[dict get $elem y1]\""
            append out " x2=\"[dict get $elem x2]\""
            append out " y2=\"[dict get $elem y2]\""
            append out " stroke=\"[dict get $elem stroke]\""
            append out " stroke-width=\"[dict get $elem strokeWidth]\""
            if {[dict get $elem strokeLinecap] ne "butt"} {
                append out " stroke-linecap=\"[dict get $elem strokeLinecap]\""
            }
            append out "/>\n"
        }
        
        polyline {
            append out "$ind<polyline"
            append out " points=\"[dict get $elem points]\""
            append out " fill=\"[dict get $elem fill]\""
            append out " stroke=\"[dict get $elem stroke]\""
            append out " stroke-width=\"[dict get $elem strokeWidth]\""
            append out "/>\n"
        }
        
        polygon {
            append out "$ind<polygon"
            append out " points=\"[dict get $elem points]\""
            append out " fill=\"[dict get $elem fill]\""
            if {[dict get $elem stroke] ne "none"} {
                append out " stroke=\"[dict get $elem stroke]\""
                append out " stroke-width=\"[dict get $elem strokeWidth]\""
            }
            append out "/>\n"
        }
        
        path {
            append out "$ind<path"
            append out " d=\"[dict get $elem d]\""
            append out " fill=\"[dict get $elem fill]\""
            if {[dict get $elem stroke] ne "none"} {
                append out " stroke=\"[dict get $elem stroke]\""
                append out " stroke-width=\"[dict get $elem strokeWidth]\""
                if {[dict get $elem strokeLinejoin] ne "miter"} {
                    append out " stroke-linejoin=\"[dict get $elem strokeLinejoin]\""
                }
                if {[dict get $elem strokeLinecap] ne "butt"} {
                    append out " stroke-linecap=\"[dict get $elem strokeLinecap]\""
                }
            }
            if {[dict get $elem id] ne ""} {
                append out " id=\"[dict get $elem id]\""
            }
            append out "/>\n"
        }
        
        text {
            append out "$ind<text"
            append out " x=\"[dict get $elem x]\""
            append out " y=\"[dict get $elem y]\""
            append out " fill=\"[dict get $elem fill]\""
            append out " font-size=\"[dict get $elem fontSize]\""
            append out " font-family=\"[dict get $elem fontFamily]\""
            if {[dict get $elem fontWeight] ne "normal"} {
                append out " font-weight=\"[dict get $elem fontWeight]\""
            }
            if {[dict get $elem textAnchor] ne "start"} {
                append out " text-anchor=\"[dict get $elem textAnchor]\""
            }
            if {[dict get $elem dominantBaseline] ne "auto"} {
                append out " dominant-baseline=\"[dict get $elem dominantBaseline]\""
            }
            append out ">[_escape [dict get $elem content]]</text>\n"
        }
        
        g {
            append out "$ind<g"
            if {[dict get $elem transform] ne ""} {
                append out " transform=\"[dict get $elem transform]\""
            }
            if {[dict get $elem opacity] < 1} {
                append out " opacity=\"[dict get $elem opacity]\""
            }
            if {[dict get $elem id] ne ""} {
                append out " id=\"[dict get $elem id]\""
            }
            append out ">\n"
            foreach child [dict get $elem children] {
                append out [_renderElement $child [expr {$indent + 1}]]
            }
            append out "$ind</g>\n"
        }
        
        linearGradient {
            append out "$ind<linearGradient"
            append out " id=\"[dict get $elem id]\""
            append out " x1=\"[dict get $elem x1]%\""
            append out " y1=\"[dict get $elem y1]%\""
            append out " x2=\"[dict get $elem x2]%\""
            append out " y2=\"[dict get $elem y2]%\">\n"
            foreach stop [dict get $elem stops] {
                lassign $stop offset color opacity
                if {$opacity eq ""} {set opacity 1}
                append out "${ind}  <stop offset=\"$offset%\" stop-color=\"$color\""
                if {$opacity < 1} {
                    append out " stop-opacity=\"$opacity\""
                }
                append out "/>\n"
            }
            append out "$ind</linearGradient>\n"
        }
        
        radialGradient {
            append out "$ind<radialGradient"
            append out " id=\"[dict get $elem id]\""
            append out " cx=\"[dict get $elem cx]%\""
            append out " cy=\"[dict get $elem cy]%\""
            append out " r=\"[dict get $elem r]%\">\n"
            foreach stop [dict get $elem stops] {
                lassign $stop offset color opacity
                if {$opacity eq ""} {set opacity 1}
                append out "${ind}  <stop offset=\"$offset%\" stop-color=\"$color\""
                if {$opacity < 1} {
                    append out " stop-opacity=\"$opacity\""
                }
                append out "/>\n"
            }
            append out "$ind</radialGradient>\n"
        }
    }
    
    return $out
}

proc ::tclutils::tusvg::toString {svg} {
    set out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    append out "<svg"
    append out " xmlns=\"[dict get $svg xmlns]\""
    append out " width=\"[dict get $svg width]\""
    append out " height=\"[dict get $svg height]\""
    if {[dict get $svg viewBox] ne ""} {
        append out " viewBox=\"[dict get $svg viewBox]\""
    }
    if {[dict get $svg id] ne ""} {
        append out " id=\"[dict get $svg id]\""
    }
    append out ">\n"
    
    # Defs
    set defs [dict get $svg defs]
    if {[llength $defs] > 0} {
        append out "  <defs>\n"
        foreach def $defs {
            append out [_renderElement $def 2]
        }
        append out "  </defs>\n"
    }
    
    # Children
    foreach child [dict get $svg children] {
        append out [_renderElement $child 1]
    }
    
    append out "</svg>\n"
    return $out
}

proc ::tclutils::tusvg::write {svg filename} {
    set content [toString $svg]
    set f [open $filename w]
    fconfigure $f -encoding utf-8
    puts -nonewline $f $content
    close $f
    return $filename
}

# ============================================================
# Vordefinierte Icons fuer Toolbars
# ============================================================

proc ::tclutils::tusvg::icon {name size args} {
    array set opts {
        -color "#333333"
        -strokeWidth ""
    }
    array set opts $args
    
    # Automatische strokeWidth basierend auf Groesse
    # Kleinere Icons = duennere Linien
    if {$opts(-strokeWidth) eq ""} {
        if {$size <= 16} {
            set opts(-strokeWidth) 1.5
        } elseif {$size <= 24} {
            set opts(-strokeWidth) 1.75
        } elseif {$size <= 32} {
            set opts(-strokeWidth) 2.0
        } else {
            set opts(-strokeWidth) 2.5
        }
    }
    
    set svg [create $size $size -viewBox "0 0 24 24"]
    set c $opts(-color)
    set sw $opts(-strokeWidth)
    
    switch $name {
        file - document {
            path svg "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            polyline svg "14,2 14,8 20,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinejoin round -strokeLinecap round
        }
        
        folder {
            path svg "M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
        }
        
        save {
            path svg "M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            polyline svg "17,21 17,13 7,13 7,21" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinejoin round -strokeLinecap round
            polyline svg "7,3 7,8 15,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinejoin round -strokeLinecap round
        }
        
        open - folder-open {
            path svg "M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2v11z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            path svg "M2 10h20" -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        plus {
            line svg 12 5 12 19 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 5 12 19 12 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        minus {
            line svg 5 12 19 12 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        x - close {
            line svg 18 6 6 18 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 6 6 18 18 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        check {
            polyline svg "20,6 9,17 4,12" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        search {
            circle svg 11 11 8 -fill "none" -stroke $c -strokeWidth $sw
            line svg 21 21 16.65 16.65 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        settings - gear {
            circle svg 12 12 3 -fill "none" -stroke $c -strokeWidth $sw
            path svg "M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
        }
        
        edit - pencil {
            path svg "M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            path svg "M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
        }
        
        trash - delete {
            polyline svg "3,6 5,6 21,6" -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round
            path svg "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            line svg 10 11 10 17 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 14 11 14 17 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        copy {
            rect svg 9 9 13 13 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            path svg "M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
        }
        
        undo {
            path svg "M3 7v6h6" -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            path svg "M21 17a9 9 0 0 0-9-9 9 9 0 0 0-6 2.3L3 13" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
        }
        
        redo {
            path svg "M21 7v6h-6" -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            path svg "M3 17a9 9 0 0 1 9-9 9 9 0 0 1 6 2.3l3 2.7" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
        }
        
        zoom-in {
            circle svg 11 11 8 -fill "none" -stroke $c -strokeWidth $sw
            line svg 21 21 16.65 16.65 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 11 8 11 14 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 11 14 11 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        zoom-out {
            circle svg 11 11 8 -fill "none" -stroke $c -strokeWidth $sw
            line svg 21 21 16.65 16.65 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 11 14 11 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        arrow-left {
            line svg 19 12 5 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "12,19 5,12 12,5" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        arrow-right {
            line svg 5 12 19 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "12,5 19,12 12,19" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        arrow-up {
            line svg 12 19 12 5 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "5,12 12,5 19,12" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        arrow-down {
            line svg 12 5 12 19 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "19,12 12,19 5,12" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        play {
            polygon svg "5,3 19,12 5,21 5,3" -fill $c -stroke "none"
        }
        
        pause {
            rect svg 6 4 4 16 -fill $c -stroke "none" -rx 1
            rect svg 14 4 4 16 -fill $c -stroke "none" -rx 1
        }
        
        stop {
            rect svg 4 4 16 16 -fill $c -stroke "none" -rx 2
        }
        
        menu - hamburger {
            line svg 3 12 21 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 3 6 21 6 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 3 18 21 18 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        home {
            path svg "M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            polyline svg "9,22 9,12 15,12 15,22" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinejoin round -strokeLinecap round
        }
        
        info {
            circle svg 12 12 10 -fill "none" -stroke $c -strokeWidth $sw
            line svg 12 16 12 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            circle svg 12 8 0.5 -fill $c -stroke $c -strokeWidth 1
        }
        
        help - question {
            circle svg 12 12 10 -fill "none" -stroke $c -strokeWidth $sw
            path svg "M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round
            circle svg 12 17 0.5 -fill $c -stroke $c -strokeWidth 1
        }
        
        chevron-left {
            polyline svg "15,18 9,12 15,6" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        chevron-right {
            polyline svg "9,18 15,12 9,6" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        chevron-up {
            polyline svg "18,15 12,9 6,15" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        chevron-down {
            polyline svg "6,9 12,15 18,9" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        refresh {
            polyline svg "23,4 23,10 17,10" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            polyline svg "1,20 1,14 7,14" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            path svg "M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
        }
        
        download {
            path svg "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            polyline svg "7,10 12,15 17,10" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 12 15 12 3 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        upload {
            path svg "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            polyline svg "17,8 12,3 7,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 12 3 12 15 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        print {
            polyline svg "6,9 6,2 18,2 18,9" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            path svg "M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            rect svg 6 14 12 8 -fill "none" -stroke $c -strokeWidth $sw
        }
        
        mail {
            path svg "M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            polyline svg "22,6 12,13 2,6" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        calendar {
            rect svg 3 4 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            line svg 16 2 16 6 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 2 8 6 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 3 10 21 10 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        user {
            path svg "M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            circle svg 12 7 4 -fill "none" -stroke $c -strokeWidth $sw
        }
        
        users {
            path svg "M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            circle svg 9 7 4 -fill "none" -stroke $c -strokeWidth $sw
            path svg "M23 21v-2a4 4 0 0 0-3-3.87" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            path svg "M16 3.13a4 4 0 0 1 0 7.75" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
        }
        
        star {
            polygon svg "12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26 12,2" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round
        }
        
        heart {
            path svg "M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round
        }
        
        bookmark {
            path svg "M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
        }
        
        clock {
            circle svg 12 12 10 -fill "none" -stroke $c -strokeWidth $sw
            polyline svg "12,6 12,12 16,14" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        alarm - bell {
            path svg "M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            path svg "M13.73 21a2 2 0 0 1-3.46 0" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
        }
        
        star-filled {
            polygon svg "12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26 12,2" \
                -fill $c -stroke $c -strokeWidth $sw -strokeLinejoin round
        }
        
        heart-filled {
            path svg "M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" \
                -fill $c -stroke $c -strokeWidth $sw -strokeLinejoin round
        }
        
        bookmark-filled {
            path svg "M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" \
                -fill $c -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
        }
        
        image - photo {
            rect svg 3 3 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            circle svg 8.5 8.5 1.5 -fill $c -stroke "none"
            polyline svg "21,15 16,10 5,21" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        eye {
            path svg "M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            circle svg 12 12 3 -fill "none" -stroke $c -strokeWidth $sw
        }
        
        eye-off {
            path svg "M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            line svg 1 1 23 23 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        filter {
            polygon svg "22,3 2,3 10,12.46 10,19 14,21 14,12.46 22,3" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
        }
        
        list {
            line svg 8 6 21 6 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 12 21 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 18 21 18 -stroke $c -strokeWidth $sw -strokeLinecap round
            circle svg 4 6 1 -fill $c -stroke "none"
            circle svg 4 12 1 -fill $c -stroke "none"
            circle svg 4 18 1 -fill $c -stroke "none"
        }
        
        grid {
            rect svg 3 3 7 7 -fill "none" -stroke $c -strokeWidth $sw
            rect svg 14 3 7 7 -fill "none" -stroke $c -strokeWidth $sw
            rect svg 14 14 7 7 -fill "none" -stroke $c -strokeWidth $sw
            rect svg 3 14 7 7 -fill "none" -stroke $c -strokeWidth $sw
        }
        
        sort {
            line svg 12 5 12 19 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "5,12 12,5 19,12" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        task - checkbox {
            rect svg 3 3 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
        }
        
        task-done - checkbox-checked {
            rect svg 3 3 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            polyline svg "9,11 12,14 22,4" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        note - notes {
            path svg "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            polyline svg "14,2 14,8 20,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinejoin round -strokeLinecap round
            line svg 8 13 16 13 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 17 12 17 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        cart - shopping {
            circle svg 9 21 1 -fill "none" -stroke $c -strokeWidth $sw
            circle svg 20 21 1 -fill "none" -stroke $c -strokeWidth $sw
            path svg "M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
        }
        
        tag {
            path svg "M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            circle svg 7 7 1.5 -fill $c -stroke "none"
        }
        
        pin {
            path svg "M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            circle svg 12 10 3 -fill "none" -stroke $c -strokeWidth $sw
        }
        
        link {
            path svg "M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            path svg "M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
        }
        
        attachment {
            path svg "M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
        }
        
        archive {
            polyline svg "21,8 21,21 3,21 3,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            rect svg 1 3 22 5 -fill "none" -stroke $c -strokeWidth $sw
            line svg 10 12 14 12 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        cut {
            circle svg 6 6 3 -fill "none" -stroke $c -strokeWidth $sw
            circle svg 6 18 3 -fill "none" -stroke $c -strokeWidth $sw
            line svg 20 4 8.12 15.88 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 14.47 14.48 20 20 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8.12 8.12 12 12 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        paste - clipboard {
            path svg "M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            rect svg 8 2 8 4 -fill "none" -stroke $c -strokeWidth $sw -rx 1
        }
        
        sync {
            polyline svg "23,4 23,10 17,10" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            polyline svg "1,20 1,14 7,14" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            path svg "M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
        }
        
        export {
            path svg "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            polyline svg "17,8 12,3 7,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 12 3 12 15 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        import {
            path svg "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            polyline svg "7,10 12,15 17,10" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 12 15 12 3 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        expand {
            polyline svg "15,3 21,3 21,9" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            polyline svg "9,21 3,21 3,15" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 21 3 14 10 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 3 21 10 14 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        collapse {
            polyline svg "4,14 10,14 10,20" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            polyline svg "20,10 14,10 14,4" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 14 10 21 3 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 3 21 10 14 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        fullscreen {
            polyline svg "8,3 3,3 3,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            polyline svg "21,8 21,3 16,3" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            polyline svg "3,16 3,21 8,21" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            polyline svg "16,21 21,21 21,16" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        pdf {
            path svg "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            polyline svg "14,2 14,8 20,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinejoin round -strokeLinecap round
            line svg 8 13 12 13 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 17 16 17 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        markdown - md {
            rect svg 2 4 20 16 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            polyline svg "7,8 7,16 10,12 13,16 13,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            polyline svg "17,12 19,14 17,16" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        back {
            line svg 19 12 5 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "12,19 5,12 12,5" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        forward {
            line svg 5 12 19 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "12,5 19,12 12,19" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        up {
            line svg 12 19 12 5 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "5,12 12,5 19,12" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        rotate_left - rotate-left {
            path svg "M1 4v6h6" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            path svg "M3.51 15a9 9 0 1 0 2.13-9.36L1 10" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
        }
        
        rotate_right - rotate-right {
            path svg "M23 4v6h-6" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            path svg "M20.49 15a9 9 0 1 1-2.12-9.36L23 10" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
        }
        
        flip_horizontal - flip-horizontal {
            line svg 12 3 12 21 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "16,7 20,12 16,17" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            polyline svg "8,7 4,12 8,17" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        flip_vertical - flip-vertical {
            line svg 3 12 21 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "7,8 12,4 17,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            polyline svg "7,16 12,20 17,16" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        fit {
            rect svg 3 3 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            rect svg 7 7 10 10 -fill "none" -stroke $c -strokeWidth $sw
        }
        
        slideshow {
            rect svg 2 6 20 12 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            polygon svg "10,9 10,15 15,12 10,9" -fill $c -stroke "none"
        }
        
        window_minimize - minimize {
            line svg 5 12 19 12 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        window_maximize - maximize {
            rect svg 3 3 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 1
        }
        
        window_restore - restore {
            rect svg 6 6 15 15 -fill "none" -stroke $c -strokeWidth $sw -rx 1
            polyline svg "9,6 9,3 21,3 21,15 18,15" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        lock {
            rect svg 3 11 18 11 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            path svg "M7 11V7a5 5 0 0 1 10 0v4" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        unlock {
            rect svg 3 11 18 11 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            path svg "M7 11V7a5 5 0 0 1 9.9-1" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        warning {
            path svg "M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round
            line svg 12 9 12 13 -stroke $c -strokeWidth $sw -strokeLinecap round
            circle svg 12 17 0.5 -fill $c -stroke $c -strokeWidth 1
        }
        
        error {
            circle svg 12 12 10 -fill "none" -stroke $c -strokeWidth $sw
            line svg 15 9 9 15 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 9 9 15 15 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        success {
            circle svg 12 12 10 -fill "none" -stroke $c -strokeWidth $sw
            polyline svg "9,12 11,14 15,10" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        duplicate {
            rect svg 9 9 13 13 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            path svg "M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            line svg 12 15 12 19 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 10 17 14 17 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        history {
            circle svg 12 12 10 -fill "none" -stroke $c -strokeWidth $sw
            polyline svg "12,6 12,12 16,14" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            path svg "M1 12a11 11 0 0 1 2.8-7.4" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round
        }
        
        run {
            polygon svg "5,3 19,12 5,21 5,3" -fill $c -stroke "none"
        }
        
        priority - priority_high - flag {
            path svg "M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round
            line svg 4 22 4 15 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        priority_low {
            line svg 12 5 12 15 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "5,12 12,19 19,12" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        deadline - clock_alert {
            circle svg 12 12 10 -fill "none" -stroke $c -strokeWidth $sw
            polyline svg "12,6 12,12 15,15" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 20 5 22 3 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        reminder {
            path svg "M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            path svg "M13.73 21a2 2 0 0 1-3.46 0" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            circle svg 18 5 3 -fill "none" -stroke $c -strokeWidth $sw
        }
        
        event - event_add {
            rect svg 3 4 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            line svg 16 2 16 6 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 2 8 6 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 3 10 21 10 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 12 14 12 18 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 10 16 14 16 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        day {
            circle svg 12 12 5 -fill "none" -stroke $c -strokeWidth $sw
            line svg 12 1 12 3 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 12 21 12 23 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 4.22 4.22 5.64 5.64 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 18.36 18.36 19.78 19.78 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 1 12 3 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 21 12 23 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 4.22 19.78 5.64 18.36 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 18.36 5.64 19.78 4.22 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        week {
            rect svg 3 4 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            line svg 3 10 21 10 -stroke $c -strokeWidth $sw
            line svg 9 4 9 22 -stroke $c -strokeWidth $sw
            line svg 15 4 15 22 -stroke $c -strokeWidth $sw
        }
        
        month {
            rect svg 3 4 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            line svg 16 2 16 6 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 2 8 6 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 3 10 21 10 -stroke $c -strokeWidth $sw
        }
        
        contact - address {
            path svg "M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round -strokeLinejoin round
            circle svg 9 7 4 -fill "none" -stroke $c -strokeWidth $sw
            line svg 23 11 17 11 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 23 7 17 7 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 23 15 20 15 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        category {
            rect svg 3 3 7 7 -fill "none" -stroke $c -strokeWidth $sw -rx 1
            rect svg 14 3 7 7 -fill "none" -stroke $c -strokeWidth $sw -rx 1
            rect svg 3 14 7 7 -fill "none" -stroke $c -strokeWidth $sw -rx 1
            rect svg 14 14 7 7 -fill "none" -stroke $c -strokeWidth $sw -rx 1
        }
        
        console - terminal {
            rect svg 2 4 20 16 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            polyline svg "6,9 10,12 6,15" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 12 15 18 15 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        debug {
            circle svg 12 12 3 -fill "none" -stroke $c -strokeWidth $sw
            path svg "M12 1v4M12 19v4M4.22 4.22l2.83 2.83M16.95 16.95l2.83 2.83M1 12h4M19 12h4M4.22 19.78l2.83-2.83M16.95 7.05l2.83-2.83" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        log {
            path svg "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            polyline svg "14,2 14,8 20,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinejoin round -strokeLinecap round
            line svg 8 12 16 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 16 16 16 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 20 12 20 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        script {
            path svg "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round -strokeLinecap round
            polyline svg "14,2 14,8 20,8" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinejoin round -strokeLinecap round
            polyline svg "8,13 10,15 8,17" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 12 15 16 15 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        package {
            path svg "M12.89 1.45l8 4A2 2 0 0 1 22 7.24v9.53a2 2 0 0 1-1.11 1.79l-8 4a2 2 0 0 1-1.79 0l-8-4a2 2 0 0 1-1.1-1.8V7.24a2 2 0 0 1 1.11-1.79l8-4a2 2 0 0 1 1.78 0z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round
            polyline svg "2.32,6.16 12,11 21.68,6.16" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 12 22 12 11 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        widget {
            rect svg 3 3 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            line svg 3 9 21 9 -stroke $c -strokeWidth $sw
            line svg 9 21 9 9 -stroke $c -strokeWidth $sw
        }
        
        theme {
            circle svg 12 12 10 -fill "none" -stroke $c -strokeWidth $sw
            path svg "M12 2a10 10 0 0 0 0 20" -fill $c -stroke $c -strokeWidth $sw
        }
        
        offline {
            line svg 1 1 23 23 -stroke $c -strokeWidth $sw -strokeLinecap round
            path svg "M16.72 11.06A10.94 10.94 0 0 1 19 12.55" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round
            path svg "M5 12.55a10.94 10.94 0 0 1 5.17-2.39" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round
            path svg "M10.71 5.05A16 16 0 0 1 22.58 9" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round
            path svg "M1.42 9a15.91 15.91 0 0 1 4.7-2.88" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round
            path svg "M8.53 16.11a6 6 0 0 1 6.95 0" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round
            circle svg 12 20 1 -fill $c -stroke "none"
        }
        
        conflict {
            path svg "M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" \
                -fill "none" -stroke $c -strokeWidth $sw -strokeLinejoin round
            line svg 12 9 12 13 -stroke $c -strokeWidth $sw -strokeLinecap round
            circle svg 12 17 0.5 -fill $c -stroke $c -strokeWidth 1
        }
        
        add {
            circle svg 12 12 10 -fill "none" -stroke $c -strokeWidth $sw
            line svg 12 8 12 16 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 12 16 12 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        select - select_all {
            rect svg 3 3 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            polyline svg "9,11 12,14 22,4" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
        }
        
        view_tree - tree {
            line svg 8 6 21 6 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 8 12 21 12 -stroke $c -strokeWidth $sw -strokeLinecap round
            line svg 12 18 21 18 -stroke $c -strokeWidth $sw -strokeLinecap round
            polyline svg "3,6 3,18 8,18" -fill "none" -stroke $c -strokeWidth $sw \
                -strokeLinecap round -strokeLinejoin round
            line svg 3 12 8 12 -stroke $c -strokeWidth $sw -strokeLinecap round
        }
        
        view_details - details {
            rect svg 3 3 18 18 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            line svg 3 9 21 9 -stroke $c -strokeWidth $sw
            line svg 3 15 21 15 -stroke $c -strokeWidth $sw
            line svg 9 9 9 21 -stroke $c -strokeWidth $sw
        }
        
        default {
            # Fallback: Rechteck mit Fragezeichen-Andeutung
            rect svg 4 4 16 16 -fill "none" -stroke $c -strokeWidth $sw -rx 2
            circle svg 12 15 0.5 -fill $c -stroke $c -strokeWidth 1
            path svg "M10 10a2 2 0 1 1 2 2v1" -fill "none" -stroke $c -strokeWidth $sw -strokeLinecap round
        }
    }
    
    return $svg
}

# ============================================================
# Convenience: Icon direkt als Datei speichern
# ============================================================

proc ::tclutils::tusvg::saveIcon {name size filename args} {
    set svg [icon $name $size {*}$args]
    write $svg $filename
    return $filename
}

# ============================================================
# Liste aller verfügbaren Icons
# ============================================================

proc ::tclutils::tusvg::icons {} {
    return {
        file document folder save open folder-open
        plus minus x close check search settings gear edit trash delete
        copy undo redo zoom-in zoom-out
        arrow-left arrow-right arrow-up arrow-down
        chevron-left chevron-right chevron-up chevron-down
        play pause stop run menu hamburger home info help
        refresh download upload print mail
        calendar clock alarm bell user users star heart bookmark
        star-filled heart-filled bookmark-filled
        image photo eye eye-off filter list grid sort
        task checkbox task-done checkbox-checked note notes
        cart shopping tag pin link attachment archive
        cut paste clipboard sync export import expand collapse fullscreen
        pdf markdown md back forward up
        rotate-left rotate-right flip-horizontal flip-vertical fit slideshow
        minimize maximize restore lock unlock
        warning error success duplicate history
        priority flag priority_low deadline reminder
        event day week month contact address category
        console terminal debug log script package widget theme
        offline conflict add select select_all view_tree tree view_details details
    }
}


package provide tclutils::tusvg 0.2
