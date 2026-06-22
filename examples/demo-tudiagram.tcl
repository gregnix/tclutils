#!/usr/bin/env tclsh
# demo-tudiagram.tcl — box-and-arrow diagrams from a Tcl model, one render path
# to SVG OR PNG (only the backend constructor differs).

source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tudiagram

set outDir [file join $::tclutils_example_dir demo-tudiagram-out]
file mkdir $outDir

# 1) linear pipeline ---------------------------------------------------------
set d [::tclutils::tudiagram::create -direction LR -theme pipeline]
foreach {id lbl} {md Markdown ast AST ir DocIR} {
    set d [::tclutils::tudiagram::addNode $d $id -label $lbl]
}
set d [::tclutils::tudiagram::addEdge $d md ast]
set d [::tclutils::tudiagram::addEdge $d ast ir]
::tclutils::tudiagram::writeSvg $d [file join $outDir pipeline.svg]
::tclutils::tudiagram::writePng $d [file join $outDir pipeline.png]

# 2) fork / merge (shows 2D layered layout) ----------------------------------
set g [::tclutils::tudiagram::create -direction LR -theme default]
foreach {id lbl} {build Build compile Compile test Test link Link pkg Package} {
    set g [::tclutils::tudiagram::addNode $g $id -label $lbl -shape rounded]
}
foreach {a b} {build compile build test compile link test link link pkg} {
    set g [::tclutils::tudiagram::addEdge $g $a $b]
}
::tclutils::tudiagram::writeSvg $g [file join $outDir fork.svg]
::tclutils::tudiagram::writePng $g [file join $outDir fork.png]

puts "wrote pipeline.{svg,png} and fork.{svg,png} to $outDir"
puts "same render proc, two backends — SVG and PNG now both render rounded boxes (tupngdraw >= 0.12)"
