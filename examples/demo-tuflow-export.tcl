#!/usr/bin/env tclsh
# demo-tuflow-export.tcl
#
# Export an arbitrary Markdown file to BOTH HTML and PDF through the
# mdstack -> docir pipeline, with tuflow flow-diagram blocks rendered:
#   HTML : ```mermaid via mermaid.js, ```flow/```tuflow as inline tuflow SVG
#   PDF  : flow/tuflow/mermaid blocks as embedded PNG (3x sharp);
#          non-flowchart Mermaid types fall back to a source code block.
#
# Usage:
#   tclsh demo-tuflow-export.tcl <input.md> ?-o <outdir>? ?-font <ttf>?
#   tclsh demo-tuflow-export.tcl            (uses a built-in sample)
#
#   -o <outdir>   where to write <base>.html / <base>.pdf (default: next to md)
#   -font <ttf>   render PDF diagram labels in a real font (needs tudiagram >=
#                 0.2 and the Glyphs package); omitted = 6x8 bitmap.
#
# Requires (installed on tcl::tm::path / auto_path):
#   mdstack::html, mdstack::pdf, docir, pdf4tcl, pdf4tcllib,
#   tclutils::tuflow, tclutils::tudiagram (+ tusvg/tupngdraw/common).

# Put tclutils (tuflow/tudiagram/...) on the path, like the other examples.
# mdstack/docir/pdf4tcl are expected from your normal tm path (~/.tclshrc).
source [file join [file dirname [info script]] bootstrap.tcl]

package require mdstack::parser
package require mdstack::html
package require mdstack::pdf

# --- argument parsing --------------------------------------------------------
set md ""
set outdir ""
set font ""
for {set i 0} {$i < [llength $argv]} {incr i} {
    set a [lindex $argv $i]
    switch -glob -- $a {
        -o     { set outdir [lindex $argv [incr i]] }
        -font  { set font   [lindex $argv [incr i]] }
        -*     { puts stderr "unknown option: $a"; exit 2 }
        default { set md $a }
    }
}

# --- built-in sample if no file given ---------------------------------------
if {$md eq ""} {
    set md [file join [file dirname [file normalize [info script]]] \
                out tuflow-export-sample.md]
    file mkdir [file dirname $md]
    set fh [open $md w]
    puts $fh {# tuflow export demo

## Flowchart
```flow
flowchart LR
    A[Start] --> B{Ready?}
    B -->|yes| C([Build])
    B -->|no| A
    C --> D[Ship]
```

## State diagram  (tuflow delegates to tustate)
```flow
stateDiagram-v2
    [*] --> Idle
    Idle --> Running : start
    Running --> Idle : stop
    Running --> [*]
```

## Requirement diagram  (tuflow delegates to turequirement)
```flow
requirementDiagram
    requirement r1 {
        id: 1
        text: must be fast
        risk: high
    }
    element e1 {
        type: simulation
    }
    e1 - satisfies -> r1
```

## A type tuflow does not render
In PDF this falls back to a source code block; in HTML mermaid.js renders it.
```mermaid
sequenceDiagram
    Alice->>Bob: Hello
    Bob-->>Alice: Hi
```

## Plain code stays a code block
```tcl
proc greet {who} { puts "Hi $who" }
```
}
    close $fh
    puts "no input given -> using sample: $md"
}

if {![file exists $md]} { puts stderr "no such file: $md"; exit 1 }
set md   [file normalize $md]
set base [file rootname [file tail $md]]
set srcDir [file dirname $md]
if {$outdir eq ""} { set outdir $srcDir }
file mkdir $outdir

set htmlOut [file join $outdir $base.html]
set pdfOut  [file join $outdir $base.pdf]

# --- export ------------------------------------------------------------------
# HTML: flow blocks become inline SVG; mermaid blocks keep mermaid.js.
mdstack::html::exportFile $md $htmlOut -title $base -root $srcDir

# PDF: flow/mermaid blocks become embedded PNG; -flowFont is optional.
set pdfArgs [list -title $base -cid 1 -root $srcDir]
if {$font ne ""} { lappend pdfArgs -flowFont $font }
set pages [mdstack::pdf::exportFile $md $pdfOut {*}$pdfArgs]

puts "HTML: $htmlOut"
puts "PDF : $pdfOut ($pages page(s))"
