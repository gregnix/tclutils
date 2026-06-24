# turadar-0.1.tm -- parse a Mermaid `radar-beta` block and render it as a radar
# (spider / Kiviat) chart to SVG or PNG through the pure-Tcl backends (tusvg /
# tupngdraw) -- no browser. Like `tupie` / `tukanban` / `tupacket` / `tutreemap`,
# this is NOT a node-edge graph: it renders directly and is reached through the
# `tclutils::tuflow` facade (`tuflow::toSvg` / `toPng`), which dispatches
# `radar-beta` here.
#
#   set m [::tclutils::turadar::parse $text]
#   ::tclutils::turadar::writeSvg $m out.svg
#   set png [::tclutils::turadar::toPng $m -scale 3]
#
# Supported syntax (Mermaid subset):
#   radar-beta                       -> header (also bare `radar`)
#   title <text>                     -> optional title
#   axis A, B, C                     -> axes (bare ids; or id["Label"])
#   axis m["Math"], s["Science"]     -> may repeat; ids accumulate in order
#   curve id["Label"]{v1, v2, ...}   -> a data series, values in axis order
#   curve id{ ax2: 30, ax1: 20 }     -> key-value form (by axis id)
#   max <n> / min <n>                -> value scale (default min 0, max = data)
#   ticks <n>                        -> number of graticule rings (default 5)
#   graticule circle|polygon         -> ring shape (default circle)
#   showLegend true|false            -> legend toggle (default: on if labelled)
#   %% ...                           -> comment
#
# Each axis radiates from the centre at 360/N spacing (first axis at the top).
# A curve plots one point per axis at radius proportional to (value-min)/(max-min)
# and connects them into a closed polygon outline.
#
# v1 limitations (honest):
#   - curves are straight-edged polygons (no Catmull-Rom spline smoothing); each
#     gets a translucent area fill plus a solid outline and vertex dots
#   - one curve per `curve` line (comma-joined multi-curve lines not split)
#   - theme / config / cScale styling is ignored
#   - needs at least 3 axes (a polygon needs >= 3 points)
#
# Namespace: ::tclutils::turadar   Package: tclutils::turadar 0.1
# Errors:    {TCLUTILS TURADAR <REASON>}   REASON in EMPTY|AXES|VALUE|ARG|FONT

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::turadar {
    namespace export parse toSvg toPng writeSvg writePng

    variable palette {
        #4e79a7 #f28e2b #e15759 #76b7b2 #59a14f
        #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac
    }
}

# --- helpers -----------------------------------------------------------------

proc ::tclutils::turadar::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TURADAR $reason] $msg
}

proc ::tclutils::turadar::_num {s what} {
    set s [string trim $s]
    if {![string is double -strict $s]} { _err VALUE "$what is not a number: $s" }
    return [expr {double($s)}]
}

# Parse one "id" or "id[\"Label\"]" token -> {id label}
proc ::tclutils::turadar::_idLabel {tok} {
    set tok [string trim $tok]
    if {[regexp {^([^\[]+?)\s*\[\s*"?([^"\]]*)"?\s*\]\s*$} $tok -> id lbl]} {
        return [list [string trim $id] [string trim $lbl]]
    }
    return [list $tok $tok]
}

proc ::tclutils::turadar::_drawText {c gfont scale x y str color} {
    if {$gfont eq "" || $str eq ""} {
        $c text $x $y $str -scale $scale -color $color
        return
    }
    set cellH   [expr {8.0 * $scale}]
    set targetW [expr {[string length $str] * 6.0 * $scale}]
    set asc [$gfont get ascender]; set dsc [$gfont get descender]
    set upm [$gfont get unitsPerEm]
    set span [expr {$asc - $dsc}]
    set adv 0.0
    foreach ch [split $str ""] {
        set adv [expr {$adv + [$gfont gget [$gfont unicode2glyphIndex $ch] advanceWidth]}]
    }
    if {$span <= 0 || $upm <= 0 || $adv <= 0} {
        $c text $x $y $str -scale $scale -color $color; return
    }
    set sy [expr {$cellH / double($span)}]
    set sx [expr {$targetW / ($adv * $sy)}]
    set baseline [expr {$y + $asc * $sy}]
    set pen 0.0
    foreach ch [split $str ""] {
        set gi [$gfont unicode2glyphIndex $ch]
        set aw [$gfont gget $gi advanceWidth]
        if {$gi != 0} {
            set g [$gfont glyph $gi]
            set contours {}
            foreach cont [$g onUniformSteps 6 "at"] {
                set flat {}
                foreach pt $cont {
                    lassign $pt fx fy
                    lappend flat [expr {$x + ($pen + $fx) * $sy * $sx}] \
                                 [expr {$baseline - $fy * $sy}]
                }
                if {[llength $flat] >= 6} { lappend contours $flat }
            }
            if {[llength $contours]} { $c fillcontours $contours -color $color -rule nonzero }
            $g destroy
        }
        set pen [expr {$pen + $aw}]
    }
}

proc ::tclutils::turadar::_drawCentered {c gfont scale cx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($cx - $w/2.0)}] $ty $str $color
}

# #rrggbb + alpha (0..255) -> {r g b a}; both backends accept the 4-list form
# (tusvg emits rgba(), tupngdraw composites source-over).
proc ::tclutils::turadar::_rgba {hex a} {
    if {![regexp {^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$} $hex -> r g b]} {
        return $hex
    }
    scan $r %x r; scan $g %x g; scan $b %x b
    return [list $r $g $b $a]
}

proc ::tclutils::turadar::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 600 -height 600 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        _err ARG "-scale must be a positive integer"
    }
    return $o
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::turadar::parse {text} {
    set title ""
    set axes {}            ;# list of {id label}
    set curves {}          ;# list of {label valuesById(dict) positional(list)}
    set vmin ""; set vmax ""
    set ticks 5
    set graticule circle
    set showLegend ""
    set sawHeader 0

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {!$sawHeader} {
            if {[regexp -nocase {^radar(-beta)?\M\s*(.*)$} $line -> _ rest]} {
                set sawHeader 1
                set rest [string trim $rest]
                if {[regexp -nocase {^title\s+(.+)$} $rest -> t]} { set title [string trim $t] }
                continue
            }
            _err EMPTY "not a radar diagram (missing header)"
        }
        if {[regexp -nocase {^title\s+(.+)$} $line -> t]} { set title [string trim $t]; continue }
        if {[regexp -nocase {^axis\s+(.+)$} $line -> rest]} {
            foreach tok [split $rest ,] {
                set tok [string trim $tok]
                if {$tok eq ""} continue
                lappend axes [_idLabel $tok]
            }
            continue
        }
        if {[regexp -nocase {^curve\s+([^\s\[{]+)\s*(?:\[\s*"?([^"\]]*)"?\s*\])?\s*\{([^}]*)\}} \
                $line -> cid clbl body]} {
            set label [expr {$clbl ne "" ? $clbl : $cid}]
            set byId {}; set pos {}
            foreach item [split $body ,] {
                set item [string trim $item]
                if {$item eq ""} continue
                if {[regexp {^([^:]+):\s*(.+)$} $item -> k v]} {
                    dict set byId [string trim $k] [_num $v "curve value"]
                } else {
                    lappend pos [_num $item "curve value"]
                }
            }
            lappend curves [list $label $byId $pos]
            continue
        }
        if {[regexp -nocase {^max\s+(.+)$} $line -> v]} { set vmax [_num $v max]; continue }
        if {[regexp -nocase {^min\s+(.+)$} $line -> v]} { set vmin [_num $v min]; continue }
        if {[regexp -nocase {^ticks\s+(\d+)$} $line -> v]} { set ticks $v; continue }
        if {[regexp -nocase {^graticule\s+(circle|polygon)$} $line -> g]} {
            set graticule [string tolower $g]; continue
        }
        if {[regexp -nocase {^showLegend\s+(true|false|1|0)$} $line -> b]} {
            set showLegend [expr {$b in {true 1}}]; continue
        }
        # unknown config lines are ignored (forward-compatible)
    }

    if {!$sawHeader} { _err EMPTY "not a radar diagram (missing header)" }
    if {[llength $axes] < 3} { _err AXES "a radar chart needs at least 3 axes" }
    if {![llength $curves]} { _err EMPTY "radar diagram has no curves" }

    # resolve each curve to a flat value list in axis order
    set axisIds {}; foreach a $axes { lappend axisIds [lindex $a 0] }
    set resolved {}
    set haveLabel 0
    foreach cv $curves {
        lassign $cv label byId pos
        if {$label ne ""} { set haveLabel 1 }
        set vals {}
        if {[dict size $byId]} {
            foreach aid $axisIds {
                lappend vals [expr {[dict exists $byId $aid] ? [dict get $byId $aid] : 0.0}]
            }
        } else {
            set i 0
            foreach aid $axisIds {
                lappend vals [expr {$i < [llength $pos] ? [lindex $pos $i] : 0.0}]
                incr i
            }
        }
        lappend resolved [list $label $vals]
    }

    # scale
    if {$vmin eq ""} { set vmin 0.0 }
    if {$vmax eq ""} {
        set vmax $vmin
        foreach cv $resolved {
            foreach v [lindex $cv 1] { if {$v > $vmax} { set vmax $v } }
        }
        if {$vmax <= $vmin} { set vmax [expr {$vmin + 1.0}] }
    }
    if {$showLegend eq ""} { set showLegend $haveLabel }

    set axisLabels {}; foreach a $axes { lappend axisLabels [lindex $a 1] }
    return [dict create title $title axes $axisLabels \
        curves $resolved min $vmin max $vmax ticks $ticks \
        graticule $graticule showLegend $showLegend]
}

# --- draw --------------------------------------------------------------------

proc ::tclutils::turadar::_polyPts {cx cy r n} {
    set pts {}
    set step [expr {2*3.141592653589793/$n}]
    for {set i 0} {$i < $n} {incr i} {
        set a [expr {-3.141592653589793/2 + $i*$step}]
        lappend pts [expr {$cx + $r*cos($a)}] [expr {$cy + $r*sin($a)}]
    }
    return $pts
}

proc ::tclutils::turadar::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} { _err FONT "font file not found: $fontfile" }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""; catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

proc ::tclutils::turadar::_draw {c model o gfont} {
    variable palette
    set W [$c width]; set H [$c height]
    set fs [dict get $o -scale]
    set np [llength $palette]
    set pi 3.141592653589793

    set title  [dict get $model title]
    set axes   [dict get $model axes]
    set curves [dict get $model curves]
    set vmin   [dict get $model min]
    set vmax   [dict get $model max]
    set ticks  [dict get $model ticks]
    set grat   [dict get $model graticule]
    set legend [dict get $model showLegend]
    set n [llength $axes]

    set titleH [expr {$title ne "" ? 22*$fs : 6*$fs}]
    set margin [expr {84*$fs}]
    set cx [expr {$W/2.0}]
    set cy [expr {($H + $titleH)/2.0}]
    set R  [expr {min($W, $H-$titleH)/2.0 - $margin}]
    if {$R < 20*$fs} { set R [expr {20*$fs}] }

    $c setlinewidth $fs

    if {$title ne ""} {
        _drawCentered $c $gfont $fs [expr {$W/2.0}] [expr {6*$fs}] $title black
    }

    # graticule rings
    for {set t 1} {$t <= $ticks} {incr t} {
        set rr [expr {$R*$t/double($ticks)}]
        if {$grat eq "polygon"} {
            $c polygon [_polyPts $cx $cy $rr $n] -fill 0 -outline 1 -color #d8d8d8
        } else {
            $c circle $cx $cy $rr -fill 0 -outline 1 -color #d8d8d8
        }
    }

    # spokes + axis labels + tick value labels along the top spoke
    set rim [_polyPts $cx $cy $R $n]
    for {set i 0} {$i < $n} {incr i} {
        set px [lindex $rim [expr {2*$i}]]; set py [lindex $rim [expr {2*$i+1}]]
        $c line $cx $cy $px $py -color #c4c4c4 -width $fs
        # axis label just outside the rim
        set a [expr {-$pi/2 + $i*2*$pi/$n}]
        set lx [expr {$cx + ($R+10*$fs)*cos($a)}]
        set ly [expr {$cy + ($R+10*$fs)*sin($a)}]
        set lbl [lindex $axes $i]
        set tw [$c textwidth $lbl -scale $fs]
        # horizontal anchor by quadrant
        if {abs(cos($a)) < 0.3} { set ax [expr {$lx - $tw/2.0}] } \
        elseif {cos($a) > 0}   { set ax $lx } \
        else                   { set ax [expr {$lx - $tw}] }
        set ay [expr {sin($a) > 0 ? $ly : $ly - 8*$fs}]
        _drawText $c $gfont $fs [expr {int($ax)}] [expr {int($ay)}] $lbl #333333
    }
    # value labels at each ring along the top (vertical) axis
    for {set t 1} {$t <= $ticks} {incr t} {
        set val [expr {$vmin + ($vmax-$vmin)*$t/double($ticks)}]
        set vs [expr {$val == int($val) ? int($val) : [format %.1f $val]}]
        set ry [expr {$cy - $R*$t/double($ticks)}]
        _drawText $c $gfont $fs [expr {int($cx+3*$fs)}] [expr {int($ry-4*$fs)}] $vs #9a9a9a
    }

    # curves: pass 1 translucent area fills, pass 2 crisp outlines + vertex dots
    set span [expr {$vmax - $vmin}]
    if {$span <= 0} { set span 1.0 }
    set polys {}
    foreach cv $curves {
        set vals [lindex $cv 1]
        set pts {}
        for {set i 0} {$i < $n} {incr i} {
            set v [expr {$i < [llength $vals] ? [lindex $vals $i] : $vmin}]
            set frac [expr {($v - $vmin)/$span}]
            if {$frac < 0} { set frac 0 }
            if {$frac > 1} { set frac 1 }
            set a [expr {-$pi/2 + $i*2*$pi/$n}]
            lappend pts [expr {$cx + $R*$frac*cos($a)}] [expr {$cy + $R*$frac*sin($a)}]
        }
        lappend polys $pts
    }
    set ci 0
    foreach pts $polys {
        set col [lindex $palette [expr {$ci % $np}]]
        $c polygon $pts -fill 1 -fillcolor [_rgba $col 48] -outline 0
        incr ci
    }
    set ci 0
    foreach pts $polys {
        set col [lindex $palette [expr {$ci % $np}]]
        $c setlinewidth [expr {2*$fs}]
        $c polygon $pts -fill 0 -outline 1 -color $col
        $c setlinewidth $fs
        foreach {dx dy} $pts {
            $c circle $dx $dy [expr {3*$fs}] -fill 1 -fillcolor $col -outline 1 -color $col
        }
        incr ci
    }

    # legend (top-left)
    if {$legend} {
        set lx [expr {8*$fs}]; set ly [expr {$titleH+4*$fs}]
        set i 0
        foreach cv $curves {
            set label [lindex $cv 0]
            if {$label eq ""} { set label "curve [expr {$i+1}]" }
            set col [lindex $palette [expr {$i % $np}]]
            set sy [expr {$ly + $i*12*$fs}]
            $c rect $lx $sy [expr {$lx+9*$fs}] [expr {$sy+9*$fs}] \
                -fill 1 -fillcolor $col -outline 1 -color $col
            _drawText $c $gfont $fs [expr {int($lx+13*$fs)}] [expr {int($sy)}] $label #333333
            incr i
        }
    }
}

# --- public render -----------------------------------------------------------

proc ::tclutils::turadar::toSvg {model args} {
    set o [_opts {*}$args]
    package require tclutils::tusvg 0.2
    set c [::tclutils::tusvg::new \
        -width [dict get $o -width] -height [dict get $o -height] -background white]
    _draw $c $model $o ""
    set out [$c data]; $c destroy
    return $out
}

proc ::tclutils::turadar::toPng {model args} {
    set o [_opts {*}$args]
    package require tclutils::tupngdraw
    set sc [dict get $o -scale]
    set c [::tclutils::tupngdraw::new \
        -width  [expr {[dict get $o -width]  * $sc}] \
        -height [expr {[dict get $o -height] * $sc}] -background white]
    catch {$c setantialias 1}
    set gf [_resolveFont $c [dict get $o -fontfile]]
    if {[catch {_draw $c $model $o $gf} err opt]} {
        catch {$gf destroy}; catch {$c destroy}
        return -options $opt $err
    }
    catch {$gf destroy}
    set out [$c data]; $c destroy
    return $out
}

proc ::tclutils::turadar::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]; fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg; close $fh
    return $file
}

proc ::tclutils::turadar::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]; puts -nonewline $fh $png; close $fh
    return $file
}

package provide tclutils::turadar 0.1
