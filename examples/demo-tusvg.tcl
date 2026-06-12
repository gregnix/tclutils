# Demo: tclutils::tusvg -- build SVG documents and an icon sheet.
# Run from the source tree; writes its output next to this script.
source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tusvg

set outDir [file join $::tclutils_example_dir demo-tusvg-out]
file mkdir $outDir

# 1) A small composed drawing -------------------------------------------------
set svg [::tclutils::tusvg::create 120 80 -viewBox {0 0 120 80}]
set grad [::tclutils::tusvg::linearGradient svg sky 0 0 0 100 \
    {{0 "#bcd9ff"} {100 "#4a90d9"}}]
::tclutils::tusvg::rect svg 0 0 120 80 -fill $grad
::tclutils::tusvg::circle svg 92 20 12 -fill "#ffe98a"
::tclutils::tusvg::polygon svg "10,70 40,30 60,70" -fill "#2e7d32"
::tclutils::tusvg::polygon svg "45,70 80,25 110,70" -fill "#1b5e20"
::tclutils::tusvg::textElement svg 8 16 "tusvg" -fill "#10243e" \
    -fontSize 14 -fontWeight bold
set f1 [::tclutils::tusvg::write $svg [file join $outDir scene.svg]]
puts "wrote $f1"

# 2) An icon sheet of every predefined icon ----------------------------------
set names [lsort [::tclutils::tusvg::icons]]
set cols  10
set cell  28
set rows  [expr {([llength $names] + $cols - 1) / $cols}]
set sheet [::tclutils::tusvg::create [expr {$cols * $cell}] [expr {$rows * $cell}]]
set i 0
foreach name $names {
    set cx [expr {($i % $cols) * $cell}]
    set cy [expr {($i / $cols) * $cell}]
    # render the named icon and nest it via a translated group
    set g [::tclutils::tusvg::group sheet -transform "translate($cx,$cy) scale([expr {$cell/24.0}])"]
    set ic [::tclutils::tusvg::icon $name 24 -color "#333333"]
    foreach child [dict get $ic children] {
        ::tclutils::tusvg::addToGroup g $child
    }
    ::tclutils::tusvg::addGroup sheet $g
    incr i
}
set f2 [::tclutils::tusvg::write $sheet [file join $outDir icons.svg]]
puts "wrote $f2 ([llength $names] icons)"

# 3) A single icon straight to file ------------------------------------------
set f3 [::tclutils::tusvg::saveIcon save 48 [file join $outDir save.svg] -color "#1565c0"]
puts "wrote $f3"
puts "open the .svg files in a browser or viewer to inspect them"
