#!/usr/bin/env tclsh
# demo-tupngdraw.tcl — erweiterte Demo für tclutils::tupngdraw 0.11
# Zeigt Formen, Text (inkl. Umlaute), Alpha, Bögen, Ellipsen, Linienstile.
#
#   tclsh demo-tupngdraw.tcl ?ausgabe.png?

source [file join [file dirname [info script]] bootstrap.tcl]

package require tclutils::tupngdraw

set out [expr {[llength $argv] ? [file normalize [lindex $argv 0]] \
    : [file join [file dirname [info script]] out tupngdraw showcase.png]}]
if {[llength $argv] && [string match *.png [file tail $out]]} {
    # argv ist direkt die PNG-Datei
} elseif {[llength $argv]} {
    set out [file join $out showcase.png]
}
file mkdir [file dirname $out]

set W 640
set H 480
set p [::tclutils::tupngdraw::new -width $W -height $H -background {248 249 250}]

# --- Titelleiste -------------------------------------------------------------
$p setfill {52 73 94}
$p rect 0 0 [expr {$W - 1}] 44 -fill 1 -outline 0
$p setfill white
$p text 16 12 "tupngdraw 0.11 — Showcase" -scale 2
$p text 16 28 "Ae Oe Ue ae oe ue ss — antialiased raster" -scale 1 -color {220 220 220}

# --- Raster (dezent) ---------------------------------------------------------
$p setstroke {230 230 230}
$p setlinewidth 1
for {set x 0} {$x < $W} {incr x 40} { $p line $x 50 $x [expr {$H - 1}] }
for {set y 50} {$y < $H} {incr y 40} { $p line 0 $y [expr {$W - 1}] $y }

# --- Panel: Grundformen --------------------------------------------------------
$p setfill white
$p setstroke {120 120 120}
$p setlinewidth 2
$p rect 20 60 300 280 -fill 1
$p setfill {66 133 244}
$p rect 40 80 130 150 -fill 1 -outline 1
$p setfill {234 67 53 180}
$p circle 220 115 45 -fill 1 -outline 0
$p setfill {251 188 5}
$p ellipse 220 200 55 30 -fill 1 -outline 1
$p setstroke {46 125 50}
$p setlinewidth 3
$p polygon {40 170 90 250 140 170 90 210} -fill 0 -outline 1 -join round

# --- Panel: Bögen & Linien ---------------------------------------------------
$p setfill white
$p setstroke {120 120 120}
$p setlinewidth 2
$p rect 320 60 620 280 -fill 1
$p setfill {156 39 176 120}
$p arc 420 170 50 0 270 -fill 1 -style pie
$p setstroke {0 150 136}
$p setlinewidth 4
$p line 340 90 600 90 -caps round
$p setstroke {255 87 34}
$p setlinewidth 2
$p line 340 110 600 250 -caps butt
$p setstroke {63 81 181}
$p setlinewidth 6
$p line 340 260 600 130 -caps square

# --- Panel: Alpha-Kompositing (überlappende Kreise) ----------------------------
$p setfill white
$p rect 20 300 300 460 -fill 1
$p setfill {244 67 54 140};  $p circle 100 380 55 -fill 1 -outline 0
$p setfill {33 150 243 140}; $p circle 150 380 55 -fill 1 -outline 0
$p setfill {76 175 80 140};  $p circle 125 420 55 -fill 1 -outline 0
$p setfill {50 50 50}
$p text 30 440 "source-over alpha" -scale 1

# --- Panel: Pixel & Text -----------------------------------------------------
$p setfill white
$p rect 320 300 620 460 -fill 1
for {set i 0} {$i < 8} {incr i} {
    set c [format #%02x%02x%02x [expr {40 + $i * 25}] 100 [expr {200 - $i * 20}]]
    $p setfill $c
    $p setpixel [expr {340 + $i * 28}] 320
}
$p setfill {33 33 33}
$p text 340 340 "0123456789 ABCDEF" -scale 2
$p text 340 370 "tupng + zlib, no Tk" -scale 1 -color {100 100 100}

# --- Rahmen ------------------------------------------------------------------
$p setstroke {52 73 94}
$p setlinewidth 3
$p rect 2 2 [expr {$W - 3}] [expr {$H - 3}] -fill 0 -outline 1

$p write $out -compression 9
$p destroy

puts "geschrieben: $out  (${W}x${H}, [file size $out] bytes)"
