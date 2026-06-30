# tupie-0.1.tm -- a Mermaid-style pie chart renderer for the tuflow family.
# Description: a Mermaid-style pie chart renderer for the tuflow family.
# Category: Diagrams · Mermaid
#
# Parses a Mermaid `pie` block into a small model dict and renders it to SVG or
# PNG with the pure-Tcl drawing backends (tusvg / tupngdraw). A pie chart is not
# a node-edge graph, so it does NOT go through tudiagram; instead tupie owns its
# own parse + draw, exposing the same toSvg/toPng shape tudiagram uses, so the
# tuflow facade can treat every diagram family uniformly.
#
#   set m [::tclutils::tupie::parse $text]
#   ::tclutils::tupie::writeSvg $m out.svg
#   set png [::tclutils::tupie::toPng $m -scale 3]
#
# Supported v1 (Mermaid pie subset):
#   - header:  pie                    (any combination, in this order)
#              pie showData
#              pie title <text>
#              pie showData title <text>
#   - title:   title <text>           (alternatively on its own line)
#   - slices:  "<label>" : <value>    (quotes optional; value int or float)
#   - comments: %% ...
# A wedge is drawn as a filled polygon (centre plus arc-sampled rim points), so
# the same routine renders identically on the raster and the SVG backend.
#
# Slice labels carry the percentage near the wedge; the legend (default on)
# lists label and percentage, plus the raw value when showData is set. Without
# -fontfile, text uses the 6x8 bitmap font (German umlauts via real codepoints).
# With -fontfile on the raster backend, labels use a real TTF via fillcontours
# (lazy Glyphs, ungebundled). The SVG backend ignores -fontfile.
#
# Namespace: ::tclutils::tupie   Package: tclutils::tupie 0.1
# Errors:    {TCLUTILS TUPIE <REASON>}   REASON in EMPTY|VALUE|FONT|ARG

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tupie {
    namespace export parse toSvg toPng writeSvg writePng

    # A fixed qualitative palette (tab10-like). Cycles when there are more
    # slices than colours.
    variable palette {
        #4e79a7 #f28e2b #e15759 #76b7b2 #59a14f
        #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac
    }
}

# --- helpers -----------------------------------------------------------------

proc ::tclutils::tupie::_unquote {s} {
    set s [string trim $s]
    set n [string length $s]
    if {$n >= 2} {
        set a [string index $s 0]
        set b [string index $s end]
        if {($a eq "\"" && $b eq "\"") || ($a eq "'" && $b eq "'")} {
            return [string range $s 1 end-1]
        }
    }
    return $s
}

# Draw a single line of text. Mirrors tudiagram::_drawText: bitmap by default,
# or a real outline font (gfont) squeezed into the same 6x8 metric box, so the
# SVG and raster layouts stay congruent.
proc ::tclutils::tupie::_drawText {c gfont scale x y str color} {
    if {$gfont eq "" || $str eq ""} {
        $c text $x $y $str -scale $scale -color $color
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
        $c text $x $y $str -scale $scale -color $color
        return
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
                    lappend flat \
                        [expr {$x + ($pen + $fx) * $sy * $sx}] \
                        [expr {$baseline - $fy * $sy}]
                }
                if {[llength $flat] >= 6} { lappend contours $flat }
            }
            if {[llength $contours]} {
                $c fillcontours $contours -color $color -rule nonzero
            }
            $g destroy
        }
        set pen [expr {$pen + $aw}]
    }
}

# Centre a string horizontally around cx at baseline-top ty.
proc ::tclutils::tupie::_drawCentered {c gfont scale cx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($cx - $w / 2.0)}] $ty $str $color
}

proc ::tclutils::tupie::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 480 -height 320 -legend 1 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        return -code error -errorcode {TCLUTILS TUPIE ARG} \
            "-scale must be a positive integer"
    }
    return $o
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tupie::parse {text} {
    set title ""
    set showData 0
    set slices {}
    set sawHeader 0
    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {!$sawHeader && [regexp -nocase {^pie\y(.*)$} $line -> rest]} {
            set sawHeader 1
            set rest [string trim $rest]
            if {[regexp -nocase {^showData\y(.*)$} $rest -> rest2]} {
                set showData 1
                set rest [string trim $rest2]
            }
            if {[regexp -nocase {^title\s+(.+)$} $rest -> t]} {
                set title [_unquote $t]
            }
            continue
        }
        if {[regexp -nocase {^title\s+(.+)$} $line -> t]} {
            set title [_unquote $t]
            continue
        }
        # slice:  label : value   (label up to the last colon before the value)
        if {[regexp {^(.+):\s*([0-9]+(?:\.[0-9]+)?)\s*$} $line -> lbl val]} {
            set lbl [_unquote [string trim $lbl]]
            if {$lbl eq ""} continue
            lappend slices [list $lbl $val]
        }
    }
    if {![llength $slices]} {
        return -code error -errorcode {TCLUTILS TUPIE EMPTY} \
            "no data slices found in pie source"
    }
    set sum 0.0
    foreach s $slices { set sum [expr {$sum + [lindex $s 1]}] }
    if {$sum <= 0} {
        return -code error -errorcode {TCLUTILS TUPIE VALUE} \
            "pie slice values must sum to a positive number"
    }
    return [dict create title $title showData $showData slices $slices]
}

# --- draw (shared across backends) -------------------------------------------

proc ::tclutils::tupie::_draw {c model o gfont} {
    variable palette
    set W  [$c width]
    set H  [$c height]
    set fs [dict get $o -scale]
    set legend [dict get $o -legend]

    set title    [dict get $model title]
    set showData [dict get $model showData]
    set slices   [dict get $model slices]
    set sum 0.0
    foreach s $slices { set sum [expr {$sum + [lindex $s 1]}] }

    set pad     [expr {12 * $fs}]
    set titleH  [expr {$title ne "" ? 18 * $fs : 0}]
    set lw      [expr {$fs}]

    # legend column on the right (if on); pie fills the remaining left box
    set legendW [expr {$legend ? int($W * 0.42) : 0}]
    set pieR    [expr {$W - $legendW}]
    set boxX0   $pad
    set boxX1   [expr {$pieR - $pad}]
    set boxY0   [expr {$pad + $titleH}]
    set boxY1   [expr {$H - $pad}]

    set cx [expr {($boxX0 + $boxX1) / 2.0}]
    set cy [expr {($boxY0 + $boxY1) / 2.0}]
    set r  [expr {min($boxX1 - $boxX0, $boxY1 - $boxY0) / 2.0}]
    if {$r < 4} { set r 4 }

    if {$title ne ""} {
        _drawCentered $c $gfont $fs [expr {$W / 2.0}] $pad $title black
    }

    # wedges: start at the top (-90 deg), sweep clockwise
    set a0 -90.0
    set i 0
    set np [llength $palette]
    foreach s $slices {
        lassign $s lbl val
        set sweep [expr {$val * 360.0 / $sum}]
        set a1 [expr {$a0 + $sweep}]
        set col [lindex $palette [expr {$i % $np}]]

        set pts [list [expr {int($cx)}] [expr {int($cy)}]]
        set steps [expr {int(ceil($sweep / 4.0)) + 2}]
        for {set k 0} {$k <= $steps} {incr k} {
            set a [expr {($a0 + ($a1 - $a0) * $k / double($steps)) * 0.01745329252}]
            lappend pts [expr {int($cx + $r * cos($a))}] \
                        [expr {int($cy + $r * sin($a))}]
        }
        $c setlinewidth $lw
        $c polygon $pts -fill 1 -fillcolor $col -outline 1 -color white

        # percentage near the wedge, only when there is room
        if {$sweep >= 18} {
            set am [expr {(($a0 + $a1) / 2.0) * 0.01745329252}]
            set lr [expr {$r * 0.62}]
            set pct [format %.0f%% [expr {$val * 100.0 / $sum}]]
            _drawCentered $c $gfont $fs \
                [expr {$cx + $lr * cos($am)}] \
                [expr {int($cy + $lr * sin($am) - 4 * $fs)}] $pct white
        }
        set a0 $a1
        incr i
    }

    # legend: swatch + label (percentage, optional raw value)
    if {$legend} {
        set lx [expr {$pieR}]
        set ly [expr {$pad + $titleH}]
        set sw [expr {10 * $fs}]
        set rowH [expr {16 * $fs}]
        set i 0
        foreach s $slices {
            lassign $s lbl val
            set col [lindex $palette [expr {$i % $np}]]
            set pct [format %.0f%% [expr {$val * 100.0 / $sum}]]
            $c setfill $col
            $c rect $lx $ly [expr {$lx + $sw}] [expr {$ly + $sw}] \
                -fill 1 -outline 0
            set txt [expr {$showData ? "$lbl ($val, $pct)" : "$lbl $pct"}]
            _drawText $c $gfont $fs \
                [expr {$lx + $sw + 5 * $fs}] [expr {$ly + 1 * $fs}] $txt black
            set ly [expr {$ly + $rowH}]
            incr i
            if {$ly + $rowH > $H} break
        }
    }
}

# Resolve an optional real outline font for the raster backend. Returns the
# Glyphs handle or "". A set-but-missing file is a hard error; a missing Glyphs
# package degrades silently to the bitmap font (best effort).
proc ::tclutils::tupie::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} {
        return -code error -errorcode {TCLUTILS TUPIE FONT} \
            "font file not found: $fontfile"
    }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""
    catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

# --- public render -----------------------------------------------------------

proc ::tclutils::tupie::toSvg {model args} {
    set o [_opts {*}$args]
    package require tclutils::tusvg 0.2
    set c [::tclutils::tusvg::new \
        -width [dict get $o -width] -height [dict get $o -height] \
        -background white]
    # the SVG backend has no fillcontours; -fontfile is ignored by design
    _draw $c $model $o ""
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tupie::toPng {model args} {
    set o [_opts {*}$args]
    package require tclutils::tupngdraw
    set sc [dict get $o -scale]
    set c [::tclutils::tupngdraw::new \
        -width  [expr {[dict get $o -width]  * $sc}] \
        -height [expr {[dict get $o -height] * $sc}] \
        -background white]
    catch {$c setantialias 1}
    set gf [_resolveFont $c [dict get $o -fontfile]]
    if {[catch {_draw $c $model $o $gf} err opt]} {
        catch {$gf destroy}
        catch {$c destroy}
        return -options $opt $err
    }
    catch {$gf destroy}
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tupie::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tupie::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tupie 0.1
