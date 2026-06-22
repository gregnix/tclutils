#!/usr/bin/env tclsh
# demo-diagrams.tcl -- render every Mermaid-compatible diagram type that the
# tuflow facade supports, to SVG and PNG, through the pure-Tcl engine (no
# browser, no Node, no mermaid.js).
#
# tuflow::writeSvg / writePng take a diagram source and dispatch automatically:
#   * graph types (flowchart, stateDiagram, erDiagram, classDiagram,
#     requirementDiagram, mindmap, C4, block-beta, gitGraph) are parsed into the
#     tudiagram model, laid out and drawn;
#   * 2D types (pie, xychart, quadrantChart, journey, timeline, sankey, gantt,
#     sequenceDiagram) go to their self-contained renderer.
# Either way the same SVG/PNG backends are used, so output stays congruent.
#
#   tclsh demo-diagrams.tcl
#
# Besides per-diagram .svg/.png, the demo writes a self-contained HTML gallery
# (index.html) with every SVG embedded inline -- the SVGs are the pure-Tcl
# render output, so no browser engine is needed to view them.
#
# Note on Tcl quoting: diagram sources are brace-quoted literals, which is fine
# as long as their braces are balanced. erDiagram cardinalities like "o{" are
# unbalanced, so that one source uses __OB__/__CB__ placeholders + string map.

source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuflow

set outDir [file join $::tclutils_example_dir demo-diagrams-out]
file mkdir $outDir
set count 0
set gallery {}   ;# list of {name svgText} for the HTML page

proc render {name src} {
    set svg [::tclutils::tuflow::toSvg $src]
    set fh [open [file join $::outDir $name.svg] w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    ::tclutils::tuflow::writePng $src [file join $::outDir $name.png] -scale 2
    lappend ::gallery [list $name $svg]
    incr ::count
    puts "  $name -> $name.{svg,png}"
}

puts "=== Graph diagrams (parser -> tudiagram model) ==="

render flowchart {flowchart LR
    A[Start] --> B{Decision}
    B -->|yes| C([Process])
    B -- no --> D(Skip)
    C --> E((Done))
    D --> E}

render state {stateDiagram-v2
    [*] --> Idle
    Idle --> Running : start
    Running --> Idle : stop
    Running --> [*]}

# erDiagram: "o{" / "|{" are single braces -> use placeholders so the literal
# stays brace-balanced for the Tcl parser.
render er [string map [list __OB__ \{ __CB__ \}] {erDiagram
    CUSTOMER ||--o__OB__ ORDER : places
    CUSTOMER __OB__
        string name
        string email
    __CB__
    ORDER ||--|__OB__ LINE_ITEM : contains
    ORDER __OB__
        int orderNumber
    __CB__
    LINE_ITEM __OB__
        string productCode
        int quantity
    __CB__}]

render class {classDiagram
    class Animal {
        +String name
        +makeSound()
    }
    class Dog
    Animal <|-- Dog}

render requirement {requirementDiagram
    requirement r1 {
        id: 1
        text: must be fast
        risk: high
    }
    element e1 {
        type: simulation
    }
    e1 - satisfies -> r1}

render mindmap {mindmap
    root((tclutils))
        Diagrams
            Model((tudiagram))
            Facade{{tuflow}}
        Output
            SVG
            PNG}

render c4 {C4Context
    title System Context
    Person(user, "User")
    System(app, "tclutils app")
    Rel(user, app, "uses")}

render block {block-beta
    columns 3
    a["Input"] b(("Process")) c["Output"]
    d{"Decision"} e(["Stage"]) f[("Store")]}

render git {gitGraph
    commit
    branch develop
    commit
    checkout main
    merge develop
    commit}

puts "=== 2D renderers (self-contained) ==="

render pie {pie title Languages
    "Tcl" : 45
    "C" : 30
    "Other" : 25}

render xychart {xychart-beta
    title "Monthly Sales"
    x-axis [Jan, Feb, Mar, Apr]
    y-axis "Revenue" 0 --> 100
    bar [40, 65, 50, 80]
    line [30, 55, 45, 70]}

render quadrant {quadrantChart
    title Effort vs Impact
    x-axis Low --> High
    y-axis Low --> High
    quadrant-1 Quick Wins
    quadrant-2 Major Projects
    quadrant-3 Fill-ins
    quadrant-4 Thankless
    Task A: [0.3, 0.6]
    Task B: [0.7, 0.8]}

render journey {journey
    title My Working Day
    section Morning
        Wake up: 3: Me
        Coffee: 5: Me
    section Work
        Code: 4: Me, Team
        Review: 2: Me}

render timeline {timeline
    title Project Timeline
    2021 : Concept
    2022 : Prototype : Alpha
    2023 : Release}

render sankey {sankey-beta
    Source,Process,10
    Process,Output,7
    Process,Waste,3}

render gantt {gantt
    title Project Plan
    dateFormat YYYY-MM-DD
    section Design
    Spec  :done, s1, 2014-01-01, 5d
    Draft :active, after s1, 6d
    section Build
    Code  :crit, after s1, 10d}

render sequence {sequenceDiagram
    autonumber
    actor U as User
    participant S as Server
    U->>+S: Request
    S-->>-U: Response
    loop Health check
        U->>S: ping
    end}

# --- HTML gallery: embed every SVG inline (self-contained, no browser engine) -
proc writeGallery {file gallery} {
    set h "<!DOCTYPE html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">\n"
    append h "<title>tclutils diagram gallery</title>\n<style>\n"
    append h "body{font-family:system-ui,sans-serif;margin:2rem;background:#fafafa;color:#222}\n"
    append h "h1{font-size:1.4rem}\n"
    append h "section{margin:1.25rem 0;padding:1rem;border:1px solid #ddd;border-radius:8px;background:#fff}\n"
    append h "h2{font-size:1rem;color:#555;margin:0 0 .5rem;font-family:ui-monospace,monospace}\n"
    append h "svg{max-width:100%;height:auto}\n</style></head>\n<body>\n"
    append h "<h1>tclutils &mdash; Mermaid-compatible diagrams (pure Tcl)</h1>\n"
    foreach item $gallery {
        lassign $item name svg
        append h "<section><h2>$name</h2>\n$svg\n</section>\n"
    }
    append h "</body></html>\n"
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $h
    close $fh
}
writeGallery [file join $outDir index.html] $gallery
puts "wrote gallery -> index.html"

puts "wrote $count diagrams (.svg + .png) to $outDir"
