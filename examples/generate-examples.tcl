#!/usr/bin/env tclsh
# Regenerate the tupngdraw / tutablepng example PNGs, using ONLY the shipped
# modules (no external dependencies). Deterministic, so output is identical on
# Tcl 8.6 and 9.x. Month-calendar demos live in generate-month-demos.tcl.
#
#     tclsh examples/generate-examples.tcl ?output-dir?
#
# Output dir defaults to this script's own directory.

set here   [file dirname [file normalize [info script]]]
set outdir [expr {[llength $argv] ? [lindex $argv 0] : $here}]
# The optional first argument is an OUTPUT DIRECTORY (not a font -- the month
# and example generators use the built-in bitmap font / shipped modules). Make
# a missing dir; reject a path that exists but is not a directory.
if {![file isdirectory $outdir]} {
    if {[file exists $outdir]} {
        puts stderr "first argument is an OUTPUT DIRECTORY, not a file: $outdir"
        puts stderr "usage: tclsh [file tail [info script]] ?output-dir?  (omit to write next to the script)"
        exit 2
    }
    file mkdir $outdir
}
tcl::tm::path add [file normalize [file join $here .. lib tm]]

package require tclutils::tupngdraw
package require tclutils::tutablepng

proc out {name} { return [file join $::outdir $name] }

# --- 1) tupngdraw: AA fills, bevel/mitre joins, fillcontours ---------------
proc gen_showcase {} {
    set p [::tclutils::tupngdraw::new -width 460 -height 230 -background {250 250 250}]
    $p setstroke {30 30 30}
    $p text 12 10 "tupngdraw 0.7" -scale 2
    $p text 12 32 "AA fills + bevel/mitre joins + fillcontours" -scale 1
    set cx 70; set cy 135; set r 48
    $p setfill {220 70 70};  $p arc $cx $cy $r   0 110 -fill 1 -style pie
    $p setfill {70 130 220}; $p arc $cx $cy $r 110 235 -fill 1 -style pie
    $p setfill {70 190 110}; $p arc $cx $cy $r 235 360 -fill 1 -style pie
    $p setstroke {30 30 30}; $p text 44 190 "AA pie" -scale 1
    $p setfill {255 190 0}; $p polygon {150 180 195 64 240 180} -fill 1 -color {120 90 0}
    $p setfill {150 90 210}; $p ellipse 195 152 44 22 -fill 1 -outline 0
    $p setlinewidth 7; $p setstroke {30 30 30}
    $p rect 300 70 340 110 -fill 0 -join round
    $p rect 350 70 390 110 -fill 0 -join bevel
    $p rect 300 150 340 190 -fill 0 -join mitre
    $p setlinewidth 1
    $p text 300 60 "round bevel" -scale 1
    $p text 300 196 "mitre" -scale 1
    set cxs 415; set cys 135; set ro 40; set ri 16
    set star {}
    for {set k 0} {$k < 10} {incr k} {
        set ang [expr {-1.5707963 + $k * 0.6283185}]
        set rr [expr {$k % 2 == 0 ? $ro : $ro * 0.42}]
        lappend star [expr {$cxs + $rr * cos($ang)}] [expr {$cys + $rr * sin($ang)}]
    }
    set hole {}
    for {set k 0} {$k < 5} {incr k} {
        set ang [expr {-1.5707963 + $k * 1.2566370}]
        lappend hole [expr {$cxs + $ri * cos($ang)}] [expr {$cys + $ri * sin($ang)}]
    }
    $p fillcontours [list $star $hole] -color {0 120 160} -rule evenodd
    $p text 392 188 "fillcontours" -scale 1
    $p write [out tupngdraw-aafills-joins.png]
}

# --- 2) tupngdraw: German umlauts / eszett in the built-in 6x8 font --------
proc gen_umlauts {} {
    set p [::tclutils::tupngdraw::new -width 250 -height 60 -background white]
    $p setstroke {20 20 20}
    $p text 4 6  "Gr\u00fc\u00dfe \u00d6l \u00dcbung" -scale 2
    $p text 4 32 "M\u00e4rz Stra\u00dfe \u00c4\u00d6\u00dc/\u00e4\u00f6\u00fc" -scale 2
    $p write [out tupngdraw-umlauts.png]
}

# --- 3) tutablepng: styled data table --------------------------------------
proc gen_table {} {
    set rows {
        {Monat   Umsatz Kosten}
        {Januar  1200   800}
        {Februar 1500   900}
        {M\u00e4rz    1800   1100}
        {April   1700   950}
    }
    set rows [lmap r $rows { lmap c $r { subst -nocommands -novariables $c } }]
    ::tclutils::tutablepng::write [out tutablepng-demo.png] $rows \
        -header 1 -align {l r r} -scale 2 -zebra {#f0f0f0}
}

gen_showcase
gen_umlauts
gen_table
puts "regenerated tupngdraw/tutablepng example PNGs in $outdir"
puts "(month calendars: run generate-month-demos.tcl)"
