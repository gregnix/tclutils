#!/usr/bin/env tclsh
# demo-tumonthpng.tcl — erweiterte Demo für tclutils::tumonthpng 0.4
# Monats-, Quartals- und Jahreskalender als PNG (Themes, Auswahl, Feiertage).
#
#   tclsh demo-tumonthpng.tcl ?ausgabe-verzeichnis?
#   tclsh demo-tumonthpng.tcl ?ausgabe-verzeichnis? -today 2026-06-15

source [file join [file dirname [info script]] bootstrap.tcl]

package require tclutils::tumonthpng

set outdir [file join [file dirname [info script]] out tumonthpng]
set today ""
set rest $argv
if {[llength $rest] > 0 && [string index [lindex $rest 0] 0] ne "-"} {
    set outdir [file normalize [lindex $rest 0]]
    set rest [lrange $rest 1 end]
}
for {set i 0} {$i < [llength $rest]} {incr i} {
    if {[lindex $rest $i] eq "-today" && $i + 1 < [llength $rest]} {
        set today [lindex $rest [incr i]]
    }
}
if {$today eq ""} {
    set today [clock format [clock seconds] -format %Y-%m-%d]
}
file mkdir $outdir

proc out {name} { return [file join $::outdir $name] }

set year 2026
set month 6

# Deutsche Feiertage / Notizen (Beispiel Juni 2026)
set holidays {
    2026-06-04  Fronleichnam
    2026-06-08  Pfingstmontag
}
set notes {
    2026-06-06  Review demos
    2026-06-15  Zahnarzt
    2026-06-22  Urlaub Start
    2026-06-29  Quartalsplanung
}

# Auswahl: Einzeltage + Bereich
set selection {
    2026-06-06
    2026-06-08..2026-06-12
    2026-06-22..2026-06-26
}

puts "tumonthpng extended demo -> $outdir"
puts "  -today $today"

# --- 1) Drei Themes, gleicher Monat ------------------------------------------
foreach theme {default dark light} {
    ::tclutils::tumonthpng::write [out month-$theme.png] $year $month \
        -theme $theme -scale 2 -today $today \
        -holidays $holidays -notes $notes \
        -select $selection -selectstyle both -selectcolor #1565C0
    puts "  [out month-$theme.png]"
}

# --- 2) Ohne Kalenderwochen-Spalte -------------------------------------------
::tclutils::tumonthpng::write [out month-noweeks.png] $year $month \
    -theme default -scale 2 -today $today \
    -holidays $holidays -notes $notes -showweeks 0
puts "  [out month-noweeks.png]"

# --- 3) Nur Outline-Auswahl ----------------------------------------------------
::tclutils::tumonthpng::write [out month-select-outline.png] $year $month \
    -theme light -scale 2 -today $today \
    -select $selection -selectstyle outline -selectcolor #E65100
puts "  [out month-select-outline.png]"

# --- 4) Layout-Varianten (Jan, Feb, Dez) -------------------------------------
foreach m {1 2 12} {
    set f [out [format month-2026-%02d.png $m]]
    ::tclutils::tumonthpng::write $f 2026 $m \
        -theme default -scale 2 -today $today
    puts "  $f"
}

# --- 5) Quartal Q2 (Apr–Jun) -------------------------------------------------
::tclutils::tumonthpng::writeQuarter [out quarter-2026-Q2.png] 2026 4 \
    -theme default -scale 2 -today $today \
    -holidays $holidays -notes $notes \
    -select {2026-05-01 2026-06-01..2026-06-05}
puts "  [out quarter-2026-Q2.png]"

# --- 6) Jahresposter (3 Spalten) ---------------------------------------------
::tclutils::tumonthpng::writeYear [out year-2026.png] 2026 \
    -theme default -scale 1 -cols 3 -today $today \
    -holidays {
        2026-01-01 Neujahr
        2026-05-01 Tag der Arbeit
        2026-10-03 Tag der Deutschen Einheit
        2026-12-25 Weihnachten
    } \
    -notes {2026-08-01 Sommerferien}
puts "  [out year-2026.png]"

# --- 7) render -> bytes (ohne Datei) als API-Beispiel --------------------------
set png [::tclutils::tumonthpng::render $year $month \
    -theme dark -scale 1 -today $today -holidays $holidays]
set apiPath [out month-from-render.png]
set fid [open $apiPath w]
fconfigure $fid -translation binary
puts -nonewline $fid $png
close $fid
puts "  $apiPath  ([string length $png] bytes via render)"

puts ""
puts "Fertig: [llength [glob -nocomplain [file join $outdir *.png]]] PNGs in $outdir"
