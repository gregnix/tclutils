# tclutils::tucodepng -- render a character-code table (ASCII / Latin-1) to a
# PNG image: a classic code-page grid where each cell shows the hex code and the
# glyph. Data comes from tclutils::tucode (lookup); drawing from tclutils::tupngdraw.
# Pure Tcl, no Tk.
#
#   package require tclutils::tucodepng
#   tclutils::tucodepng::write ascii.png 0 127            ;# ASCII chart
#   tclutils::tucodepng::write latin1.png 128 255 -shownames 1
#   tclutils::tucodepng::ascii                            ;# -> PNG bytes (0..127)
#
# The built-in 6x8 bitmap font covers ASCII (and German umlauts), so 0..127
# renders fully dependency-free. For the real Latin-1 glyphs (128..255) pass a
# -textcmd that fills outline glyphs from a real font (see tumonthpng's -textcmd
# and examples/generate-codepage-glyphs-demo.tcl); the hex codes and control
# abbreviations always use the bitmap font.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tupngdraw 0.12
package require tclutils::tucode 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucodepng {
    namespace export render write ascii latin1 all
    variable version 0.1
    variable themes
}

# themes: bg cellBg controlBg latinBg fg codeFg nameFg outline titleFg
set ::tclutils::tucodepng::themes(default) {
    bg #ffffff  cellBg #ffffff  controlBg #eef0f4  latinBg #f3f7ff
    fg #111111  codeFg #909090  nameFg #707070  outline #d4d4d4  titleFg #1a1a1a
}
set ::tclutils::tucodepng::themes(dark) {
    bg #2d2d2d  cellBg #3a3a3a  controlBg #333740  latinBg #34384a
    fg #e8e8e8  codeFg #8a8a8a  nameFg #a0a0a0  outline #555555  titleFg #ffffff
}
set ::tclutils::tucodepng::themes(light) {
    bg #fafafa  cellBg #ffffff  controlBg #eef1f5  latinBg #eaf2fe
    fg #222222  codeFg #9a9a9a  nameFg #757575  outline #dddddd  titleFg #212121
}

proc ::tclutils::tucodepng::_theme {name} {
    variable themes
    if {![info exists themes($name)]} {
        return -code error -errorcode {TCLUTILS TUCODEPNG THEME} \
            "unknown theme: $name (have default|dark|light)"
    }
    return $themes($name)
}

# Draw $text centred in box (x,y,w,h). With useCmd and a -textcmd set, delegate
# (for real outline glyphs); otherwise use the bitmap font.
proc ::tclutils::tucodepng::_centre {img x y w h text color scale tcmd useCmd} {
    if {$useCmd && $tcmd ne ""} {
        {*}$tcmd $img $x $y $w $h $text $color
        return
    }
    set tw [expr {[string length $text] * 6 * $scale}]
    set th [expr {8 * $scale}]
    $img text [expr {$x + ($w - $tw) / 2}] [expr {$y + ($h - $th) / 2}] \
        $text -color $color -scale $scale
    return
}

proc ::tclutils::tucodepng::render {from to args} {
    set o [::tclutils::common::parseOptions {
        -columns 16 -scale 2 -theme default -textcmd {}
        -shownames 0 -showcode 1 -title {}
    } {*}$args]
    if {![string is integer -strict $from] || ![string is integer -strict $to]} {
        return -code error -errorcode {TCLUTILS TUCODEPNG RANGE} "from/to must be integers"
    }
    if {$from > $to} {
        return -code error -errorcode {TCLUTILS TUCODEPNG RANGE} "from > to"
    }
    if {$from < 0 || $to > 255} {
        return -code error -errorcode {TCLUTILS TUCODEPNG RANGE} "range must be within 0..255"
    }
    set th    [_theme [dict get $o -theme]]
    set s     [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]
    set cols  [::tclutils::common::ensurePositiveInteger [dict get $o -columns] -columns]
    set tcmd  [dict get $o -textcmd]
    set shownames [::tclutils::common::ensureBoolean [dict get $o -shownames] -shownames]
    set showcode  [::tclutils::common::ensureBoolean [dict get $o -showcode] -showcode]
    set title [dict get $o -title]

    # cell geometry (px)
    set pad [expr {2 * $s}]
    set codeH [expr {$showcode ? 8 + 2 : 0}]      ;# small hex line (scale 1)
    set glyphH [expr {8 * $s}]                     ;# big glyph band
    set nameH  [expr {$shownames ? 8 + 2 : 0}]     ;# small name line (scale 1)
    set ch [expr {$pad + $codeH + $glyphH + $nameH + $pad}]
    set cw [expr {max(28 * $s, ($shownames ? 48 : 0))}]
    set titleH [expr {$title ne "" ? 12 * $s : 0}]

    set count [expr {$to - $from + 1}]
    set rows  [expr {($count + $cols - 1) / $cols}]
    set W [expr {$cols * $cw}]
    set H [expr {$titleH + $rows * $ch}]

    set img [::tclutils::tupngdraw::new -width $W -height $H -background [dict get $th bg]]

    if {$titleH > 0} {
        _centre $img 0 0 $W $titleH $title [dict get $th titleFg] $s {} 0
    }

    for {set i 0} {$i < $count} {incr i} {
        set code [expr {$from + $i}]
        set col [expr {$i % $cols}]
        set row [expr {$i / $cols}]
        set x [expr {$col * $cw}]
        set y [expr {$titleH + $row * $ch}]

        set info [::tclutils::tucode::lookup $code]
        set isControl [expr {$code < 32 || $code == 127}]
        set isSpace   [expr {$code == 32}]
        set isLatin   [expr {$code >= 128}]

        if {$isControl || $isSpace} {
            set bg [dict get $th controlBg]
        } elseif {$isLatin} {
            set bg [dict get $th latinBg]
        } else {
            set bg [dict get $th cellBg]
        }

        $img setfill $bg
        $img setstroke [dict get $th outline]
        $img setlinewidth 1
        $img rect $x $y [expr {$x + $cw - 1}] [expr {$y + $ch - 1}] -fill 1

        # hex code (small, top)
        if {$showcode} {
            _centre $img $x [expr {$y + $pad}] $cw 8 \
                [dict get $info hex] [dict get $th codeFg] 1 {} 0
        }

        # centre band: big glyph for printable, small abbreviation for control/space
        set gy [expr {$y + $pad + $codeH}]
        if {$isControl} {
            _centre $img $x $gy $cw $glyphH [dict get $info name] [dict get $th fg] 1 {} 0
        } elseif {$isSpace} {
            _centre $img $x $gy $cw $glyphH "SP" [dict get $th fg] 1 {} 0
        } else {
            # printable (33..126) or Latin-1 (128..255): draw the actual char.
            # Bitmap font covers ASCII; Latin-1 needs -textcmd (else blank).
            _centre $img $x $gy $cw $glyphH [dict get $info char] [dict get $th fg] $s $tcmd 1
        }

        # name (small, bottom) -- optional
        if {$shownames} {
            set ny [expr {$y + $pad + $codeH + $glyphH + 2}]
            _centre $img $x $ny $cw 8 [dict get $info name] [dict get $th nameFg] 1 {} 0
        }
    }

    set png [$img data -compression 9]
    $img destroy
    return $png
}

proc ::tclutils::tucodepng::write {file from to args} {
    set png [render $from $to {*}$args]
    set fid [open $file w]
    fconfigure $fid -translation binary
    puts -nonewline $fid $png
    close $fid
    return $file
}

proc ::tclutils::tucodepng::ascii  {args} { return [render 0 127 {*}$args] }
proc ::tclutils::tucodepng::latin1 {args} { return [render 128 255 {*}$args] }
proc ::tclutils::tucodepng::all    {args} { return [render 0 255 {*}$args] }

package provide tclutils::tucodepng 0.1
