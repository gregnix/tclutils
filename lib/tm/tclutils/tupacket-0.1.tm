# tupacket-0.1.tm -- parse and render a Mermaid `packet-beta` block to SVG or
# PNG through the pure-Tcl backends (tusvg / tupngdraw), so a packet/bit-field
# layout can be shown natively everywhere -- no browser. Like `tupie` /
# `tukanban`, this is NOT a node-edge graph: it renders directly and is reached
# through the `tclutils::tuflow` facade (`tuflow::toSvg` / `toPng`), which
# dispatches `packet-beta` here.
#
#   set m [::tclutils::tupacket::parse $text]
#   ::tclutils::tupacket::writeSvg $m out.svg
#   set png [::tclutils::tupacket::toPng $m -scale 3]
#
# Supported syntax (Mermaid subset):
#   packet-beta                          -> header (also bare `packet`)
#   title <text>                         -> optional (or `packet-beta title <t>`)
#   <start>-<end>: "Label"               -> a bit range, inclusive
#   <bit>: "Label"                       -> a single bit (start == end)
#   %% ...                               -> comment
#
# The label may be quoted ("..." / '...') or bare. Fields are sorted by start
# bit; overlapping ranges or an end-before-start are a parse error. Bits that no
# field covers, within the used range, are drawn as light-grey gap cells.
#
# Layout (v1): bits are laid out 32 per row (the Mermaid default). A field that
# crosses a row boundary is split into per-row segments sharing one colour; its
# label is drawn once, centred in its widest segment, and clipped (not wrapped)
# if longer than the cell. Each row carries the start/end bit index of every
# segment along its top. The canvas height grows with the row count when
# `-height` is left at its default (0 = auto).
#
# v1 limitations (honest):
#   - bits-per-row is fixed at 32; Mermaid's `packet` config block is not parsed
#   - no theming or per-field colour configuration
#   - long labels are clipped to their cell, not wrapped or shrunk
#
# Without -fontfile, text uses the 6x8 bitmap font (German umlauts via real
# codepoints). With -fontfile on the raster backend, labels use a real TTF via
# fillcontours (lazy Glyphs, ungebundled). The SVG backend ignores -fontfile.
#
# Namespace: ::tclutils::tupacket   Package: tclutils::tupacket 0.1
# Errors:    {TCLUTILS TUPACKET <REASON>}   REASON in EMPTY|RANGE|VALUE|ARG|FONT

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tupacket {
    namespace export parse toSvg toPng writeSvg writePng

    # Qualitative palette (tab10-like); cycles per field.
    variable palette {
        #4e79a7 #f28e2b #e15759 #76b7b2 #59a14f
        #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac
    }

    variable BITS_PER_ROW 32

    # Layout constants (logical units; multiplied by the scale factor at draw).
    variable PAD       16
    variable TICK_H    14
    variable CELL_H    30
    variable ROW_GAP   12
}

# --- helpers -----------------------------------------------------------------

proc ::tclutils::tupacket::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUPACKET $reason] $msg
}

proc ::tclutils::tupacket::_unquote {s} {
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

proc ::tclutils::tupacket::_drawText {c gfont scale x y str color} {
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

proc ::tclutils::tupacket::_drawCentered {c gfont scale cx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($cx - $w / 2.0)}] $ty $str $color
}

proc ::tclutils::tupacket::_drawRight {c gfont scale rx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($rx - $w)}] $ty $str $color
}

# Clip a string so it fits within maxW device px at the given scale.
proc ::tclutils::tupacket::_clip {c scale str maxW} {
    set txt $str
    while {$txt ne "" && [$c textwidth $txt -scale $scale] > $maxW} {
        set txt [string range $txt 0 end-1]
    }
    return $txt
}

proc ::tclutils::tupacket::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 640 -height 0 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        _err ARG "-scale must be a positive integer"
    }
    return $o
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tupacket::parse {text} {
    variable BITS_PER_ROW
    set title ""
    set fields {}           ;# list of {start end label}
    set sawHeader 0

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {!$sawHeader} {
            if {[regexp -nocase {^packet(-beta)?\M\s*(.*)$} $line -> _ rest]} {
                set sawHeader 1
                set rest [string trim $rest]
                if {[regexp -nocase {^title\s+(.+)$} $rest -> t]} {
                    set title [_unquote [string trim $t]]
                }
                continue
            }
            _err EMPTY "not a packet diagram (missing header)"
        }
        if {[regexp -nocase {^title\s+(.+)$} $line -> t]} {
            set title [_unquote [string trim $t]]
            continue
        }
        # field:  <start>-<end>: label    or    <bit>: label
        if {[regexp {^(\d+)\s*-\s*(\d+)\s*:\s*(.*)$} $line -> a b lbl]} {
            # range
        } elseif {[regexp {^(\d+)\s*:\s*(.*)$} $line -> a lbl]} {
            set b $a
        } else {
            _err VALUE "cannot parse packet field: $line"
        }
        scan $a %d a
        scan $b %d b
        if {$b < $a} { _err RANGE "field end before start: $line" }
        lappend fields [list $a $b [_unquote [string trim $lbl]]]
    }

    if {!$sawHeader} { _err EMPTY "not a packet diagram (missing header)" }
    if {![llength $fields]} { _err EMPTY "packet diagram has no fields" }

    # sort by start bit, then check for overlaps
    set fields [lsort -integer -index 0 $fields]
    set prevEnd -1
    foreach f $fields {
        lassign $f a b
        if {$a <= $prevEnd} {
            _err RANGE "overlapping fields at bit $a"
        }
        set prevEnd $b
    }
    return [dict create title $title bitsPerRow $BITS_PER_ROW fields $fields]
}

# --- layout helpers ----------------------------------------------------------

proc ::tclutils::tupacket::_maxBit {model} {
    set mx 0
    foreach f [dict get $model fields] { set mx [expr {max($mx, [lindex $f 1])}] }
    return $mx
}

proc ::tclutils::tupacket::_rows {model} {
    set bpr [dict get $model bitsPerRow]
    return [expr {[_maxBit $model] / $bpr + 1}]
}

proc ::tclutils::tupacket::_autoHeight {model} {
    variable PAD; variable TICK_H; variable CELL_H; variable ROW_GAP
    set rows [_rows $model]
    set titleH [expr {[dict get $model title] ne "" ? 18 : 0}]
    return [expr {$PAD + $titleH + $rows * ($TICK_H + $CELL_H + $ROW_GAP) - $ROW_GAP + $PAD}]
}

# Split a field into per-row segments. Returns a list of {row a b} where a..b is
# the bit span inside that row (clamped to the row's 32-bit window).
proc ::tclutils::tupacket::_segments {a b bpr} {
    set segs {}
    set r [expr {$a / $bpr}]
    while {1} {
        set rowStart [expr {$r * $bpr}]
        set rowEnd   [expr {$rowStart + $bpr - 1}]
        set sa [expr {max($a, $rowStart)}]
        set sb [expr {min($b, $rowEnd)}]
        lappend segs [list $r $sa $sb]
        if {$b <= $rowEnd} break
        incr r
    }
    return $segs
}

# --- draw (shared across backends) -------------------------------------------

proc ::tclutils::tupacket::_draw {c model o gfont} {
    variable palette; variable PAD; variable TICK_H; variable CELL_H
    variable ROW_GAP
    set W   [$c width]
    set fs  [dict get $o -scale]
    set bpr [dict get $model bitsPerRow]
    set np  [llength $palette]

    set title  [dict get $model title]
    set fields [dict get $model fields]
    set maxBit [_maxBit $model]
    set rows   [_rows $model]

    set pad    [expr {$PAD * $fs}]
    set tickH  [expr {$TICK_H * $fs}]
    set cellH  [expr {$CELL_H * $fs}]
    set rowGap [expr {$ROW_GAP * $fs}]
    set titleH [expr {$title ne "" ? 18 * $fs : 0}]

    set x0 $pad
    set x1 [expr {$W - $pad}]
    if {$x1 - $x0 < 32} { set x1 [expr {$x0 + 32}] }
    set cellW [expr {($x1 - $x0) / double($bpr)}]

    $c setlinewidth $fs

    if {$title ne ""} {
        _drawCentered $c $gfont $fs [expr {$W / 2.0}] $pad $title black
    }

    # vertical origin of a row's tick line
    set rowY {r {
        upvar 1 pad pad titleH titleH tickH tickH cellH cellH rowGap rowGap
        expr {$pad + $titleH + $r * ($tickH + $cellH + $rowGap)}
    }}

    # x of the left edge of a bit within its row
    set bitX {bit {
        upvar 1 x0 x0 cellW cellW bpr bpr
        expr {$x0 + ($bit % $bpr) * $cellW}
    }}

    # Build per-row segment lists: gap + field cells, sorted by start bit.
    # For each field, remember which segment is widest (label goes there only).
    array set rowSegs {}
    for {set r 0} {$r < $rows} {incr r} { set rowSegs($r) {} }
    set fi 0
    foreach f $fields {
        lassign $f a b label
        set color [lindex $palette [expr {$fi % $np}]]
        set segs [_segments $a $b $bpr]
        # widest segment index (for the label)
        set best 0; set bestW -1; set k 0
        foreach s $segs {
            lassign $s r sa sb
            set w [expr {$sb - $sa}]
            if {$w > $bestW} { set bestW $w; set best $k }
            incr k
        }
        set k 0
        foreach s $segs {
            lassign $s r sa sb
            set lab [expr {$k == $best ? $label : ""}]
            lappend rowSegs($r) [list $sa $sb field $color $lab]
            incr k
        }
        incr fi
    }

    # Gap cells: within each row, bits in [rowStart..rowLastBit] not covered.
    for {set r 0} {$r < $rows} {incr r} {
        set rowStart   [expr {$r * $bpr}]
        set rowLastBit [expr {min($rowStart + $bpr - 1, $maxBit)}]
        set covered {}
        foreach seg $rowSegs($r) { lappend covered $seg }
        set covered [lsort -integer -index 0 $covered]
        set cursor $rowStart
        set gaps {}
        foreach seg $covered {
            lassign $seg sa sb
            if {$sa > $cursor} { lappend gaps [list $cursor [expr {$sa - 1}] gap #f0f0f0 ""] }
            set cursor [expr {$sb + 1}]
        }
        if {$cursor <= $rowLastBit} {
            lappend gaps [list $cursor $rowLastBit gap #f0f0f0 ""]
        }
        set rowSegs($r) [lsort -integer -index 0 [concat $rowSegs($r) $gaps]]
    }

    # Render row by row.
    for {set r 0} {$r < $rows} {incr r} {
        set ry  [apply $rowY $r]
        set cy0 [expr {$ry + $tickH}]
        set cy1 [expr {$cy0 + $cellH}]
        foreach seg $rowSegs($r) {
            lassign $seg sa sb kind color label
            set lx [apply $bitX $sa]
            set rx [expr {[apply $bitX $sb] + $cellW}]
            if {$kind eq "field"} {
                $c rect $lx $cy0 $rx $cy1 -fill 1 -fillcolor $color \
                    -outline 1 -color #2b2b2b
                if {$label ne ""} {
                    set lab [_clip $c $fs $label [expr {$rx - $lx - 6 * $fs}]]
                    _drawCentered $c $gfont $fs [expr {($lx + $rx) / 2.0}] \
                        [expr {int($cy0 + ($cellH - 8 * $fs) / 2.0)}] $lab white
                }
            } else {
                $c rect $lx $cy0 $rx $cy1 -fill 1 -fillcolor $color \
                    -outline 1 -color #d0d0d0
            }
            # bit-index ticks: start at the left, end at the right of the segment
            _drawText $c $gfont $fs [expr {$lx + 2 * $fs}] \
                [expr {int($ry + 2 * $fs)}] $sa #777777
            if {$sb != $sa} {
                _drawRight $c $gfont $fs [expr {$rx - 2 * $fs}] \
                    [expr {int($ry + 2 * $fs)}] $sb #777777
            }
        }
    }
}

# Resolve an optional real outline font for the raster backend. Returns the
# Glyphs handle or "". A set-but-missing file is a hard error; a missing Glyphs
# package degrades silently to the bitmap font (best effort).
proc ::tclutils::tupacket::_resolveFont {c fontfile} {
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

proc ::tclutils::tupacket::toSvg {model args} {
    set o [_opts {*}$args]
    set w [dict get $o -width]
    set h [dict get $o -height]; if {$h == 0} { set h [_autoHeight $model] }
    package require tclutils::tusvg 0.2
    set c [::tclutils::tusvg::new -width $w -height $h -background white]
    _draw $c $model $o ""
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tupacket::toPng {model args} {
    set o [_opts {*}$args]
    set w [dict get $o -width]
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

proc ::tclutils::tupacket::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tupacket::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tupacket 0.1
