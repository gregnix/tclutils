#!/usr/bin/env tclsh
# demo-tupng.tcl — erweiterte Demo für tclutils::tupng 0.4
# Pure-Tcl PNG Encoder/Decoder: RGB, RGBA, Gray, Indexed, Round-Trip, Filter.
#
#   tclsh demo-tupng.tcl ?ausgabe-verzeichnis?
#
# Writes PNGs to examples/out/tupng/ (or argv dir).

source [file join [file dirname [info script]] bootstrap.tcl]

package require tclutils::tupng
catch { package require tclutils::tuimage }

set outdir [expr {[llength $argv] ? [file normalize [lindex $argv 0]] \
    : [file join [file dirname [info script]] out tupng]}]
file mkdir $outdir

proc banner {msg} {
    puts [format "%-40s %s" $msg ""]
}

banner "tupng extended demo -> $outdir"

# --- 1) RGB-Verlauf 128x64 ---------------------------------------------------
set rgb {}
for {set y 0} {$y < 64} {incr y} {
    set row {}
    for {set x 0} {$x < 128} {incr x} {
        lappend row [format %02x%02x%02x [expr {$x * 2}] [expr {$y * 4}] 96]
    }
    lappend rgb $row
}
::tclutils::tupng::writeRGB [file join $outdir 01-gradient-rgb.png] $rgb -compression 9

# --- 2) RGBA — Schachbrett mit halbtransparenten Feldern ---------------------
set rgba {}
for {set y 0} {$y < 64} {incr y} {
    set row {}
    for {set x 0} {$x < 64} {incr x} {
        set on [expr {($x / 8 + $y / 8) % 2}]
        if {$on} {
            lappend row "3366CCff"
        } else {
            lappend row "3366CC40"
        }
    }
    lappend rgba $row
}
::tclutils::tupng::writeRGBA [file join $outdir 02-checker-rgba.png] $rgba

# --- 3) Graustufen-Rampe -----------------------------------------------------
set gray {}
for {set y 0} {$y < 32} {incr y} {
    set row {}
    for {set x 0} {$x < 256} {incr x} { lappend row $x }
    lappend gray $row
}
::tclutils::tupng::writeGray [file join $outdir 03-ramp-gray.png] $gray

# --- 4) Indexed — Palette mit Transparenz ------------------------------------
set pal {E53935 1E88E5 FDD835 00000000}
set idx {}
for {set y 0} {$y < 16} {incr y} {
    set row {}
    for {set x 0} {$x < 16} {incr x} {
        lappend row [expr {($x + $y) % 4}]
    }
    lappend idx $row
}
::tclutils::tupng::writeIndexed [file join $outdir 04-indexed-alpha.png] $pal $idx

# --- 5) Filter-Vergleich (gleiches Bild, unterschiedliche -filter) -----------
set small {}
for {set y 0} {$y < 32} {incr y} {
    set row {}
    for {set x 0} {$x < 32} {incr x} {
        lappend row [format %02x%02x%02x [expr {($x * 7) % 256}] [expr {($y * 11) % 256}] 128]
    }
    lappend small $row
}
foreach f {none sub paeth best} {
    ::tclutils::tupng::writeRGB [file join $outdir 05-filter-$f.png] $small -filter $f
}

# --- 6) Round-Trip: encode RGBA -> decode -> Metadaten -----------------------
set rt {}
for {set y 0} {$y < 8} {incr y} {
    set row {}
    for {set x 0} {$x < 8} {incr x} {
        lappend row [format "FF%02x00ff" [expr {32 + $x * 28}]]
    }
    lappend rt $row
}
set path [file join $outdir 06-roundtrip.png]
::tclutils::tupng::writeRGBA $path $rt
set info [::tclutils::tupng::readPNG $path]
puts "  Round-Trip: [dict get $info width]x[dict get $info height] type=[dict get $info colortype]"

# --- 7) Kompressionsgrößen-Vergleich -------------------------------------------
set tile {{888888 444444} {CCCCCC FFFFFF}}
set sizes {}
foreach level {0 3 6 9} {
    set f [file join $outdir 07-compress-$level.png]
    ::tclutils::tupng::writeRGB $f $tile -compression $level
    lappend sizes [list $level [file size $f]]
}

# --- Bericht -----------------------------------------------------------------
puts ""
puts [format "%-36s %8s %s" "Datei" "Bytes" "Info"]
puts [string repeat "-" 72]
foreach f [lsort [glob -nocomplain [file join $outdir *.png]]] {
    set ch [open $f rb]; set b [read $ch]; close $ch
    set extra ""
    if {[info commands ::tclutils::tuimage::inspect] ne ""} {
        catch { set extra [::tclutils::tuimage::inspect $b] }
    }
    puts [format "%-36s %8d %s" [file tail $f] [string length $b] $extra]
}
puts ""
puts "Kompression (2x2 RGB-Kachel):"
foreach {lev sz} $sizes {
    puts "  level $lev -> $sz bytes"
}
puts ""
puts "Fertig: [llength [glob -nocomplain [file join $outdir *.png]]] PNGs in $outdir"
