#!/usr/bin/env tclsh
# demo-tuflow.tcl — render a flowchart from compact arrow text (no browser/Node)
# through tuflow -> tudiagram -> SVG/PNG.

source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuflow

set outDir [file join $::tclutils_example_dir demo-tuflow-out]
file mkdir $outDir

set src {flowchart LR
    A[Start] --> B{Decision}
    B -->|yes| C[Process]
    B -- no --> D(Skip)
    C --> E((End))
    D --> E}

set m [::tclutils::tuflow::parse $src]
::tclutils::tudiagram::writeSvg $m [file join $outDir flow.svg]
::tclutils::tudiagram::writePng $m [file join $outDir flow.png]
puts "parsed [llength [dict get $m nodes]] nodes / [llength [dict get $m edges]] edges"
puts "wrote flow.{svg,png} to $outDir"
