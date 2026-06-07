#!/usr/bin/env tclsh
# OPTIONAL example: render a FULL code-page table (0..255, incl. the real
# Latin-1 glyphs) by passing tucodepng a -textcmd that fills outline glyphs from
# a real font via the third-party Glyphs package + tupngdraw::fillcontours.
# The bitmap font alone covers only ASCII; this shows the upper half properly.
#
# NOT part of the suite (external dependency). Glyphs and the font each carry
# their own license. Only a font FILE is required:
#
#   tclsh generate-codepage-glyphs-demo.tcl <font.ttf|otf> ?out.png? ?from? ?to?

set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tupngdraw
package require tclutils::tucodepng
if {[catch {package require Glyphs} err]} {
    puts stderr "This optional demo needs the Glyphs package on auto_path. Details: $err"
    exit 2
}

lassign $argv fontfile out from to
if {$fontfile eq "" || ![file exists $fontfile] || [file isdirectory $fontfile]} {
    puts stderr "usage: tclsh generate-codepage-glyphs-demo.tcl <font.ttf|otf> ?out.png? ?from? ?to?"
    exit 2
}
if {$out  eq ""} { set out  [file join $here codepage-glyphs.png] }
if {$from eq ""} { set from 0 }
if {$to   eq ""} { set to 255 }

set FONT [Glyphs::new $fontfile]
set UPM  [$FONT get unitsPerEm]

# -textcmd: fill the character outline centred in the cell box (x,y,w,h).
proc cellText {f upm img x y w h text color} {
    set px [expr {$h * 0.62}]
    set sc [expr {$px / double($upm)}]
    set adv 0.0
    foreach ch [split $text ""] {
        set adv [expr {$adv + [$f gget [$f unicode2glyphIndex $ch] advanceWidth]}]
    }
    set penx [expr {$x + ($w - $adv * $sc) / 2.0}]
    set baseline [expr {$y + ($h + $px * 0.70) / 2.0}]
    foreach ch [split $text ""] {
        set gi [$f unicode2glyphIndex $ch]
        set aw [$f gget $gi advanceWidth]
        if {$gi != 0} {
            set contours {}
            set g [$f glyph $gi]
            foreach c [$g onUniformSteps 5 "at"] {
                set flat {}
                foreach pt $c {
                    lassign $pt fx fy
                    lappend flat [expr {$penx + $fx * $sc}] [expr {$baseline - $fy * $sc}]
                }
                if {[llength $flat] >= 6} { lappend contours $flat }
            }
            if {[llength $contours]} { $img fillcontours $contours -color $color -rule nonzero }
            $g destroy
        }
        set penx [expr {$penx + $aw * $sc}]
    }
}

::tclutils::tucodepng::write $out $from $to \
    -scale 2 -shownames 1 -title "Code page $from-$to" -textcmd [list cellText $FONT $UPM]
$FONT destroy
puts "wrote $out  (font [file tail $fontfile], $from..$to)"
