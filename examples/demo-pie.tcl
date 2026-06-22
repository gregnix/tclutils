# demo-pie.tcl -- render Mermaid pie charts and a flow graph through the tuflow
# facade. Pure Tcl, headless (no Tk). Runs on Tcl 8.6 and 9.
#
#   tclsh demo-pie.tcl ?outdir?
#
# Produces, in outdir (default the current directory):
#   pie-browsers.png / .svg   pie with showData (label, value, percent)
#   pie-langs.png             pie without legend
#   facade-graph.svg          a flow graph via the same facade entry point

set here [file normalize [file dirname [info script]]]
tcl::tm::path add [file join $here .. lib tm]

package require tclutils::tuflow

set outdir [expr {$argc >= 1 ? [lindex $argv 0] : [pwd]}]
file mkdir $outdir

set browsers {pie showData title Browser market share
    "Chrome"  : 64
    "Safari"  : 19
    "Edge"    : 5
    "Firefox" : 3
    "Other"   : 9
}

set langs {pie title Languages in the repo
    "Tcl"   : 72
    "C"     : 14
    "Shell" : 9
    "Other" : 5
}

set graph {graph LR
    A[Source] --> B{Parse}
    B -->|ok| C[Render]
    B -->|fail| D[Report]
    C --> E[Output]
}

# pie -> PNG + SVG (scale 3 for a crisp raster)
::tclutils::tuflow::writePng $browsers [file join $outdir pie-browsers.png] -scale 3
::tclutils::tuflow::writeSvg $browsers [file join $outdir pie-browsers.svg]

# pie without the legend
::tclutils::tuflow::writePng $langs [file join $outdir pie-langs.png] -scale 3 -legend 0

# the same facade renders a graph, too
::tclutils::tuflow::writeSvg $graph [file join $outdir facade-graph.svg]

puts "wrote:"
foreach f {pie-browsers.png pie-browsers.svg pie-langs.png facade-graph.svg} {
    puts "  [file join $outdir $f]"
}
