#!/usr/bin/env tclsh
# demo-tuflow.tcl — render Mermaid-style diagrams through tuflow -> tudiagram
# -> SVG/PNG (no browser/Node). tuflow handles flowcharts directly and
# delegates stateDiagram -> tustate and requirementDiagram -> turequirement.

source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuflow

set outDir [file join $::tclutils_example_dir demo-tuflow-out]
file mkdir $outDir

proc render {name src} {
    set m [::tclutils::tuflow::parse $src]
    ::tclutils::tudiagram::writeSvg $m [file join $::outDir $name.svg]
    ::tclutils::tudiagram::writePng $m [file join $::outDir $name.png] -scale 2
    puts "  $name: [llength [dict get $m nodes]] nodes / [llength [dict get $m edges]] edges -> $name.{svg,png}"
}

render flow {flowchart LR
    A[Start] --> B{Decision}
    B -->|yes| C[Process]
    B -- no --> D(Skip)
    C --> E((End))
    D --> E}

render state {stateDiagram-v2
    [*] --> Idle
    Idle --> Running : start
    Running --> Idle : stop
    Running --> [*]}

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

# erDiagram: the cardinality (o{ / |{) and entity blocks contain "{", which
# would break Tcl brace counting in a {literal}. Use placeholders + string map.
render er [string map [list __OB__ \{ __CB__ \}] {erDiagram
    CUSTOMER ||--o__OB__ ORDER : places
    CUSTOMER __OB__
        string name
        string custNumber
    __CB__
    ORDER ||--|__OB__ LINE-ITEM : contains
    ORDER __OB__
        int orderNumber
    __CB__
    LINE-ITEM __OB__
        string productCode
        int quantity
    __CB__}]

puts "wrote flow / state / requirement / er .{svg,png} to $outDir"
