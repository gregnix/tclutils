#!/usr/bin/env tclsh
# demo-tumermaid.tcl — render a Mermaid flowchart natively (no browser/Node)
# through tumermaid -> tudiagram -> SVG/PNG.

source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tumermaid

set outDir [file join $::tclutils_example_dir demo-tumermaid-out]
file mkdir $outDir

set src {flowchart LR
    A[Start] --> B{Decision}
    B -->|yes| C[Process]
    B -- no --> D(Skip)
    C --> E((End))
    D --> E}

set m [::tclutils::tumermaid::parse $src]
::tclutils::tudiagram::writeSvg $m [file join $outDir flow.svg]
::tclutils::tudiagram::writePng $m [file join $outDir flow.png]
puts "parsed [llength [dict get $m nodes]] nodes / [llength [dict get $m edges]] edges"
puts "wrote flow.{svg,png} to $outDir"
