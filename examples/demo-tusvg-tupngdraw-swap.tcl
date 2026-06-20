#!/usr/bin/env tclsh
# demo-tusvg-tupngdraw-swap.tcl
#
# Proves the tusvg 0.2 <-> tupngdraw congruence contract: ONE drawing proc,
# using only the shared canvas API, renders unchanged on either backend — only
# the constructor differs. textwidth must agree across backends (box-sizing).
#
# Usage:  tclsh demo-tusvg-tupngdraw-swap.tcl   ->   pipe.svg + pipe.png

source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tupngdraw
package require tclutils::tusvg 0.2

# Shared API only: new / setfill / setstroke / setlinewidth / rect / line /
# polygon / text / textwidth / write.
proc drawPipeline {c} {
    set y1 30; set y2 90; set bw 120; set bh [expr {$y2-$y1}]; set gap 60
    set x 20; set rights {}
    foreach lab {Markdown AST DocIR} {
        $c setfill   "#e3f2fd"
        $c setstroke "#1565c0"
        $c setlinewidth 2
        $c rect $x $y1 [expr {$x+$bw}] $y2 -fill 1 -outline 1
        set tw [$c textwidth $lab -scale 2]
        $c text [expr {$x + ($bw-$tw)/2}] [expr {$y1 + ($bh-16)/2}] $lab \
            -scale 2 -color "#0d47a1"
        lappend rights [expr {$x+$bw}]
        set x [expr {$x+$bw+$gap}]
    }
    set midy [expr {($y1+$y2)/2}]
    foreach r [lrange $rights 0 end-1] {
        set ax2 [expr {$r+$gap}]
        $c setstroke "#555555"
        $c line $r $midy $ax2 $midy -width 3
        $c setfill "#555555"
        $c polygon [list $ax2 $midy [expr {$ax2-10}] [expr {$midy-6}] \
                         [expr {$ax2-10}] [expr {$midy+6}]] -fill 1 -outline 0
    }
}

set svg [::tclutils::tusvg::new    -width 480 -height 130 -background white]
set png [::tclutils::tupngdraw::new -width 480 -height 130 -background white]

if {[$svg textwidth Markdown -scale 2] != [$png textwidth Markdown -scale 2]} {
    error "textwidth metric differs between backends"
}

drawPipeline $svg   ;# same proc ...
drawPipeline $png   ;# ... both backends

$svg write pipe.svg
$png write pipe.png
puts "OK — pipe.svg ([file size pipe.svg] B), pipe.png ([file size pipe.png] B)"
