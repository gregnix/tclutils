#!/usr/bin/env tclsh
# Demo: tclutils::tulayout — page layout engine (pure Tcl, no Tk).

set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tulayout 0.1
namespace import ::tclutils::tulayout::*

puts "=== paper ==="
lassign [pageSize a4] pw ph
puts "A4 portrait:  ${pw} x ${ph} mm"
lassign [pageSize a4 landscape] pw ph
puts "A4 landscape: ${pw} x ${ph} mm"

puts "\n=== mm <-> px (scale 3 px/mm) ==="
set scale 3.0
set xmm 20.0
set xpx [mmToPx $xmm $scale]
puts [format "x = %.1f mm -> %.1f px -> %.1f mm" $xmm $xpx [pxToMm $xpx $scale]]

puts "\n=== snap (grid 5 mm) ==="
puts [format "12.3 mm -> %.1f mm" [snap 12.3]]
puts [format "12.6 mm -> %.1f mm (grid 10)" [snap 12.6 -grid 10]]

puts "\n=== fit page into viewport ==="
set fit [fitScale 210 297 640 480 -marginPx 20]
puts [format "A4 in 640x480 px, margin 20 -> scale %.3f px/mm" $fit]

puts "\n=== blocks ==="
set defs {
    header {label Header w 170 h 15}
    body   {label Body   w 170 h 45}
    footer {label Footer w 170 h 10 lockedY 1}
}
set blocks {
    header {label Header x 20 y 25 w 170 h 15 show 1}
    body   {label Body   x 20 y 55 w 170 h 45 show 1}
    footer {label Footer x 20 y 0  w 170 h 10 show 1 lockedY 1}
}
set blocks [ensureBlocks $blocks $defs]
puts "order:  [blockOrder $blocks $defs]"
puts "footer auto-Y? [isAutoY [dict get $blocks footer]]"
lassign [blockRect [dict get $blocks header]] x0 y0 x1 y1
puts [format "header rect: %.0f,%.0f .. %.0f,%.0f mm" $x0 $y0 $x1 $y1]

puts "\n=== merge preset (only x/y/w/show) ==="
set preset {
    header {x 30 show 1}
    body   {x 25 w 160 show 0}
}
set merged [mergeBlocks $blocks $preset]
puts "header x: [dict get $merged header x]  (was 20, preset 30)"
puts "body show: [dict get $merged body show]  (preset hides body)"
puts "body y:   [dict get $merged body y]    (unchanged — not in preset)"

set doc [dict create paper a4 margin 20 blocks $blocks]
set doc [mergeLayout $doc [dict create blocks $preset]]
puts "mergeLayout header x: [dict get $doc blocks header x]"
