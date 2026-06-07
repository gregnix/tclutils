#!/usr/bin/env tclsh
# OPTIONAL example: render a tumonthpng month calendar whose LABELS are drawn
# from a real TrueType/OpenType font, by passing tumonthpng a -textcmd that
# fills glyph outlines (via the third-party Glyphs package) with
# tupngdraw::fillcontours. tumonthpng keeps full control of layout, themes and
# cell colours; only the text is outline-rendered -- so umlauts in month names
# ("Maerz" -> "Marz" with the proper umlaut) come out correctly and the type
# scales cleanly.
#
# NOT part of the suite (external dependency). Glyphs and the font each carry
# their own license. Only a font FILE is required:
#
#   tclsh generate-month-glyphs-demo.tcl <font.ttf|otf> ?out.png? ?year? ?month?

set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tupngdraw
package require tclutils::tumonthpng
if {[catch {package require Glyphs} err]} {
    puts stderr "This optional demo needs the Glyphs package on auto_path."
    puts stderr "In tclsh, 'package require Glyphs' must work. Details: $err"
    exit 2
}

lassign $argv fontfile out year month
if {$fontfile eq ""} {
    puts stderr "usage: tclsh generate-month-glyphs-demo.tcl <font.ttf|otf> ?out.png? ?year? ?month?"
    exit 2
}
if {![file exists $fontfile] || [file isdirectory $fontfile]} {
    puts stderr "pass a font FILE: $fontfile"
    exit 2
}
if {$out   eq ""} { set out   [file join $here month-glyphs.png] }
if {$year  eq ""} { set year  2026 }
if {$month eq ""} { set month 6 }

set FONT [Glyphs::new $fontfile]
set UPM  [$FONT get unitsPerEm]

# A -textcmd: draw $text centred in the cell box (x,y,w,h) using outline glyphs.
# Picks its pixel size from the box height; centres horizontally on the measured
# advance width and vertically on an approximate cap height.
proc cellText {f upm img x y w h text color} {
    set px [expr {$h * 0.58}]
    set sc [expr {$px / double($upm)}]
    # measure advance width in px
    set adv 0.0
    foreach ch [split $text ""] {
        set adv [expr {$adv + [$f gget [$f unicode2glyphIndex $ch] advanceWidth]}]
    }
    set tw [expr {$adv * $sc}]
    set penx [expr {$x + ($w - $tw) / 2.0}]
    set baseline [expr {$y + ($h + $px * 0.70) / 2.0}]
    foreach ch [split $text ""] {
        set gi [$f unicode2glyphIndex $ch]
        set aw [$f gget $gi advanceWidth]
        if {$gi != 0} {
            set g [$f glyph $gi]
            set contours {}
            foreach c [$g onUniformSteps 5 "at"] {
                set flat {}
                foreach pt $c {
                    lassign $pt fx fy
                    lappend flat [expr {$penx + $fx * $sc}] [expr {$baseline - $fy * $sc}]
                }
                if {[llength $flat] >= 6} { lappend contours $flat }
            }
            if {[llength $contours]} {
                $img fillcontours $contours -color $color -rule nonzero
            }
            $g destroy
        }
        set penx [expr {$penx + $aw * $sc}]
    }
}

::tclutils::tumonthpng::write $out $year $month \
    -scale 2 -today [format %04d-%02d-06 $year $month] \
    -holidays [list [format %04d-%02d-08 $year $month] Pfingstmontag] \
    -notes    [list [format %04d-%02d-15 $year $month] Zahnarzt \
                    [format %04d-%02d-22 $year $month] Urlaub] \
    -textcmd [list cellText $FONT $UPM]
$FONT destroy
puts "wrote $out  (font [file tail $fontfile], $year-[format %02d $month])"
