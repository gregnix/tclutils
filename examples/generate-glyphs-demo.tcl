#!/usr/bin/env tclsh
# OPTIONAL example: render real TrueType/OpenType text through tupngdraw's
# fillcontours, using the third-party "Glyphs" package to extract glyph
# outlines. NOT part of the tclutils PNG suite -- it adds an external
# dependency and only demonstrates that fillcontours consumes real outlines.
#
# Requirements (install yourself): the Glyphs package (pure Tcl, by A. Buratti;
# it pulls in its bundled Bezier/BContour itself) and a .ttf/.otf font file.
# Glyphs and the font each carry their own license.
#
# Usage:
#   tclsh generate-glyphs-demo.tcl <font.ttf|otf> ?em-px? ?text-utf8-file? ?out.png?
#
# Only the font file is required. Defaults: em = 40, a built-in demo string,
# output = fillcontours-glyphs-demo.png next to this script. If you pass a text
# file, it is read as UTF-8 (so non-ASCII survives any system encoding); do not
# pass the text on the command line.

set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tupngdraw

# Requiring Glyphs is enough -- it adds its own lib/ to auto_path and pulls in
# Bezier/BContour. (Do NOT require Bezier separately: it is only reachable once
# Glyphs has loaded.)
if {[catch {package require Glyphs} err]} {
    puts stderr "This optional demo needs the Glyphs package on auto_path."
    puts stderr "In tclsh, 'package require Glyphs' must work. Details: $err"
    exit 2
}

lassign $argv fontfile em txtfile out
if {$fontfile eq ""} {
    puts stderr "usage: tclsh generate-glyphs-demo.tcl <font.ttf|otf> ?em? ?text-utf8-file? ?out.png?"
    exit 2
}
if {[file isdirectory $fontfile]} {
    puts stderr "Pass a font FILE, not a directory, e.g.:"
    puts stderr "  tclsh generate-glyphs-demo.tcl [file join $fontfile arial.ttf]"
    exit 2
}
if {![file exists $fontfile]} {
    puts stderr "font file not found: $fontfile"
    exit 2
}
if {$em eq ""}  { set em 40 }
if {$out eq ""} { set out [file join $here fillcontours-glyphs-demo.png] }

# text: from a UTF-8 file if given, else a built-in default (escaped, so the
# source stays ASCII and encoding-independent).
if {$txtfile ne "" && [file exists $txtfile]} {
    set fid [open $txtfile r]; fconfigure $fid -encoding utf-8
    set text [string trimright [read $fid] "\n"]; close $fid
} else {
    set text "tupngdraw fillcontours \u2014 \u00c4\u00d6\u00dc \u00e4\u00f6\u00fc \u00df caf\u00e9 1234"
}

set f [Glyphs::new $fontfile]
set upm [$f get unitsPerEm]; set asc [$f get ascender]; set dsc [$f get descender]
set scale [expr {double($em) / $upm}]; set margin 6

set pen 0.0
foreach ch [split $text ""] {
    set pen [expr {$pen + [$f gget [$f unicode2glyphIndex $ch] advanceWidth]}]
}
set W [expr {int(ceil($pen * $scale)) + 2 * $margin}]
set H [expr {int(ceil(($asc - $dsc) * $scale)) + 2 * $margin}]
set baseY [expr {$margin + $asc * $scale}]

set img [::tclutils::tupngdraw::new -width $W -height $H -background white]
set pen 0.0
foreach ch [split $text ""] {
    set gi [$f unicode2glyphIndex $ch]
    set aw [$f gget $gi advanceWidth]
    if {$gi != 0} {
        set g [$f glyph $gi]
        set contours {}
        foreach c [$g onUniformSteps 6 "at"] {
            set flat {}
            foreach pt $c {
                lassign $pt fx fy
                lappend flat [expr {$margin + ($pen + $fx) * $scale}] \
                             [expr {$baseY - $fy * $scale}]
            }
            if {[llength $flat] >= 6} { lappend contours $flat }
        }
        if {[llength $contours]} {
            $img fillcontours $contours -color {20 20 20} -rule nonzero
        }
        $g destroy
    }
    set pen [expr {$pen + $aw}]
}
$f destroy
$img write $out
puts "wrote $out  ${W}x${H}  (font [file tail $fontfile], em $em)"
