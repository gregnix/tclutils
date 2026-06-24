# tukanban-0.1.tm -- a Mermaid-style kanban renderer for the tuflow family.
#
# Parses a Mermaid `kanban` block into a small model dict and renders it to SVG
# or PNG with the pure-Tcl drawing backends (tusvg / tupngdraw). A kanban board
# is a column layout, not a node-edge graph, so it does NOT go through tudiagram;
# instead tukanban owns its own parse + draw and exposes the same toSvg/toPng
# shape the other 2D renderers use, so the tuflow facade treats every diagram
# family uniformly.
#
#   set m [::tclutils::tukanban::parse $text]
#   ::tclutils::tukanban::writeSvg $m out.svg
#   set png [::tclutils::tukanban::toPng $m -scale 3]
#
# Supported v1 (Mermaid kanban subset):
#   - header:    kanban
#   - column:    <Title>                  (least-indented content line)
#   - card:      <Text>                    (a more-indented line)
#                <Text>@{ key: val, ... }  (optional metadata)
#   - comments:  %% ...
#
# Indentation decides the role: the first content line after the header sets the
# column-indent; lines at that indent are column titles, deeper lines are cards
# of the current column. Card metadata after `@{ ... }` is shown as a small grey
# sub-line (all parsed `key: value` pairs, joined). Only the keys present are
# shown -- the Mermaid keys `ticket`, `assigned`, `priority` are typical but not
# required.
#
# v1 limitations (honest):
#   - `priority` is pulled out and shown as a colour badge (High/Medium/Low/
#     Critical); the remaining metadata is rendered as a single grey text line
#   - no card colours, no assignee avatars
#   - long card text is clipped to the column width, not wrapped
#
# Without -fontfile, text uses the 6x8 bitmap font (German umlauts via real
# codepoints). With -fontfile on the raster backend, labels use a real TTF via
# fillcontours (lazy Glyphs, ungebundled). The SVG backend ignores -fontfile.
#
# Namespace: ::tclutils::tukanban   Package: tclutils::tukanban 0.1
# Errors:    {TCLUTILS TUKANBAN <REASON>}   REASON in EMPTY|ARG|FONT

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tukanban {
    namespace export parse toSvg toPng writeSvg writePng

    # Fixed qualitative palette for column headers (tab10-like); cycles.
    variable palette {
        #4e79a7 #f28e2b #e15759 #76b7b2 #59a14f
        #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac
    }

    # Layout constants (logical units; multiplied by the scale factor at draw).
    variable PAD       14
    variable COL_W     190
    variable HEADER_H  30
    variable CARD_H1   30
    variable CARD_H2   44
    variable CARD_GAP  10
}

# --- helpers -----------------------------------------------------------------

proc ::tclutils::tukanban::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUKANBAN $reason] $msg
}

proc ::tclutils::tukanban::_indent {raw} {
    set n 0
    foreach ch [split $raw ""] {
        if {$ch eq " "} { incr n } \
        elseif {$ch eq "\t"} { incr n 4 } \
        else break
    }
    return $n
}

# Pull `text@{ k: v, k2: v2 }` apart. Returns {text metaText}, where metaText is
# the parsed pairs joined as "k: v  k2: v2" (empty if there was no @{...}).
proc ::tclutils::tukanban::_splitMeta {s} {
    set s [string trim $s]
    set at [string first "@\{" $s]
    if {$at < 0} { return [list $s ""] }
    set text [string trim [string range $s 0 [expr {$at - 1}]]]
    set rest [string range $s [expr {$at + 2}] end]
    set close [string first "\}" $rest]
    if {$close >= 0} { set rest [string range $rest 0 [expr {$close - 1}]] }
    set parts {}
    foreach pair [split $rest ","] {
        set pair [string trim $pair]
        if {$pair eq ""} continue
        lappend parts $pair
    }
    return [list $text [join $parts "  "]]
}

proc ::tclutils::tukanban::_drawText {c gfont scale x y str color} {
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

proc ::tclutils::tukanban::_drawCentered {c gfont scale cx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($cx - $w / 2.0)}] $ty $str $color
}

# Clip a string so it fits within maxW device px at the given scale.
proc ::tclutils::tukanban::_clip {c scale str maxW} {
    set txt $str
    while {$txt ne "" && [$c textwidth $txt -scale $scale] > $maxW} {
        set txt [string range $txt 0 end-1]
    }
    return $txt
}

proc ::tclutils::tukanban::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 0 -height 0 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        _err ARG "-scale must be a positive integer"
    }
    return $o
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tukanban::parse {text} {
    set columns {}           ;# list of {title cards}, card = {text meta}
    set curTitle ""
    set curCards {}
    set haveCol 0
    set sawHeader 0
    set colIndent -1
    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {!$sawHeader} {
            if {[regexp -nocase {^kanban\M} $line]} { set sawHeader 1; continue }
            _err EMPTY "not a kanban diagram (missing header)"
        }
        set ind [_indent $raw]
        if {$colIndent < 0} { set colIndent $ind }
        if {$ind <= $colIndent} {
            # new column title -> flush previous column
            if {$haveCol} { lappend columns [list $curTitle $curCards] }
            set curTitle $line
            set curCards {}
            set haveCol 1
        } else {
            # a card of the current column
            lassign [_splitMeta $line] ctext cmeta
            lappend curCards [list $ctext $cmeta]
        }
    }
    if {!$sawHeader} { _err EMPTY "not a kanban diagram (missing header)" }
    if {$haveCol} { lappend columns [list $curTitle $curCards] }
    if {![llength $columns]} { _err EMPTY "kanban diagram has no columns" }
    return [dict create columns $columns]
}

# --- layout / draw -----------------------------------------------------------

proc ::tclutils::tukanban::_cardH {card} {
    variable CARD_H1; variable CARD_H2
    return [expr {[lindex $card 1] ne "" ? $CARD_H2 : $CARD_H1}]
}

proc ::tclutils::tukanban::_autoWidth {model} {
    variable PAD; variable COL_W
    set n [llength [dict get $model columns]]
    return [expr {$PAD + $n * ($COL_W + $PAD)}]
}

proc ::tclutils::tukanban::_autoHeight {model} {
    variable PAD; variable HEADER_H; variable CARD_GAP
    set maxStack 0
    foreach col [dict get $model columns] {
        set cards [lindex $col 1]
        set h 0
        foreach card $cards { set h [expr {$h + [_cardH $card] + $CARD_GAP}] }
        if {$h > $maxStack} { set maxStack $h }
    }
    return [expr {$PAD + $HEADER_H + $CARD_GAP + $maxStack + $PAD}]
}

proc ::tclutils::tukanban::_draw {c model o gfont} {
    variable palette; variable PAD; variable COL_W; variable HEADER_H
    variable CARD_GAP
    set W  [$c width]
    set H  [$c height]
    set fs [dict get $o -scale]

    set columns [dict get $model columns]
    set n [llength $columns]

    set pad     [expr {$PAD * $fs}]
    set headerH [expr {$HEADER_H * $fs}]
    set gap     [expr {$CARD_GAP * $fs}]
    # column width: fill the canvas evenly
    set colW [expr {($W - $pad * ($n + 1)) / double($n)}]
    if {$colW < 20} { set colW 20 }

    $c setlinewidth $fs
    set ci 0
    set np [llength $palette]
    foreach col $columns {
        lassign $col title cards
        set cx0 [expr {$pad + $ci * ($colW + $pad)}]
        set cx1 [expr {$cx0 + $colW}]
        set ccx [expr {($cx0 + $cx1) / 2.0}]
        set hcol [lindex $palette [expr {$ci % $np}]]

        # column header band
        set hy0 $pad
        set hy1 [expr {$pad + $headerH}]
        $c setfill $hcol
        $c rect $cx0 $hy0 $cx1 $hy1 -fill 1 -outline 1 -color #2b2b2b -rx [expr {4*$fs}] -ry [expr {4*$fs}]
        _drawCentered $c $gfont $fs $ccx [expr {$hy0 + 7 * $fs}] \
            [_clip $c $fs $title [expr {$colW - 8 * $fs}]] white

        # column lane background
        set ly0 [expr {$hy1 + $gap}]
        set ly1 [expr {$H - $pad}]
        $c setfill #f4f4f4
        $c rect $cx0 $ly0 $cx1 $ly1 -fill 1 -outline 1 -color #dddddd

        # cards
        set y $ly0
        foreach card $cards {
            lassign $card ctext cmeta
            set ch [expr {[_cardH $card] * $fs}]
            set kx0 [expr {$cx0 + 4 * $fs}]
            set kx1 [expr {$cx1 - 4 * $fs}]
            set ky0 [expr {$y + 2 * $fs}]
            set ky1 [expr {$y + $ch}]
            $c setfill white
            $c rect $kx0 $ky0 $kx1 $ky1 -fill 1 -outline 1 -color #bbbbbb -rx [expr {3*$fs}] -ry [expr {3*$fs}]
            set tw [expr {$colW - 16 * $fs}]
            # pull `priority: X` out of the metadata and show it as a colour badge
            set prio ""; set metaRest $cmeta
            if {[regexp -nocase {priority:\s*([A-Za-z0-9]+)} $cmeta -> pv]} {
                set prio $pv
                regsub -nocase {priority:\s*[A-Za-z0-9]+} $metaRest "" metaRest
                set metaRest [string trim $metaRest]
                regsub -all {\s{2,}} $metaRest "  " metaRest
                set metaRest [string trim $metaRest "  "]
            }
            set titleW $tw
            if {$prio ne ""} {
                set pmap {high #e15759 medium #f28e2b low #59a14f critical #b4232e blocked #b4232e}
                set pkey [string tolower $prio]
                set pcol [expr {[dict exists $pmap $pkey] ? [dict get $pmap $pkey] : "#8a8a8a"}]
                set pw [expr {[$c textwidth $prio -scale $fs] + 8*$fs}]
                set px1 [expr {$kx1 - 4*$fs}]; set px0 [expr {$px1 - $pw}]
                $c setfill $pcol
                $c rect $px0 [expr {$ky0+3*$fs}] $px1 [expr {$ky0+13*$fs}] \
                    -fill 1 -fillcolor $pcol -outline 0 -rx [expr {3*$fs}] -ry [expr {3*$fs}]
                _drawCentered $c $gfont $fs [expr {($px0+$px1)/2.0}] [expr {$ky0+4*$fs}] $prio white
                set titleW [expr {$tw - $pw - 4*$fs}]
            }
            _drawText $c $gfont $fs [expr {$kx0 + 4 * $fs}] [expr {$ky0 + 4 * $fs}] \
                [_clip $c $fs $ctext $titleW] black
            if {$metaRest ne ""} {
                _drawText $c $gfont $fs [expr {$kx0 + 4 * $fs}] \
                    [expr {$ky0 + 16 * $fs}] [_clip $c $fs $metaRest $tw] #777777
            }
            set y [expr {$y + $ch + $gap}]
            if {$y > $ly1} break
        }
        incr ci
    }
}

# Resolve an optional real outline font for the raster backend. Returns the
# Glyphs handle or "". A set-but-missing file is a hard error; a missing Glyphs
# package degrades silently to the bitmap font (best effort).
proc ::tclutils::tukanban::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} {
        _err FONT "font file not found: $fontfile"
    }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""
    catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

# --- public render -----------------------------------------------------------

proc ::tclutils::tukanban::toSvg {model args} {
    set o [_opts {*}$args]
    set w [dict get $o -width];  if {$w == 0} { set w [_autoWidth $model] }
    set h [dict get $o -height]; if {$h == 0} { set h [_autoHeight $model] }
    package require tclutils::tusvg 0.2
    set c [::tclutils::tusvg::new -width $w -height $h -background white]
    _draw $c $model $o ""
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tukanban::toPng {model args} {
    set o [_opts {*}$args]
    set w [dict get $o -width];  if {$w == 0} { set w [_autoWidth $model] }
    set h [dict get $o -height]; if {$h == 0} { set h [_autoHeight $model] }
    package require tclutils::tupngdraw
    set sc [dict get $o -scale]
    set c [::tclutils::tupngdraw::new \
        -width [expr {$w * $sc}] -height [expr {$h * $sc}] -background white]
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

proc ::tclutils::tukanban::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tukanban::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tukanban 0.1
