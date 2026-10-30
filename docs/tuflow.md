# tclutils::tuflow

The front end of the `tuflow` diagram family: it parses a Mermaid / flowchart
source block and renders it to SVG or PNG. It is the single entry point a
consumer (e.g. a documentation renderer) calls; it detects the diagram kind and
dispatches to the right family module, so the caller never has to know whether a
block is a graph, a class diagram or a pie chart.

Everything is pure Tcl: graphs go through `tclutils::tudiagram` (a node-edge
layout over the `tclutils::tupngdraw` / `tclutils::tusvg` backends). Pie charts,
xy charts, sequences, gantt charts and the other non-graph families each have
their own module. No Tk, no browser, no external rasteriser.

## Package

```tcl
package require tclutils::tuflow 0.4
```

## Commands

```tcl
::tclutils::tuflow::parse    text                       ;# -> tudiagram model (graphs only)
::tclutils::tuflow::toSvg     text ?-opt val ...?        ;# -> SVG string
::tclutils::tuflow::toPng     text ?-opt val ...?        ;# -> PNG bytes
::tclutils::tuflow::writeSvg  text file ?-opt val ...?   ;# -> file (SVG)
::tclutils::tuflow::writePng  text file ?-opt val ...?   ;# -> file (PNG)
```

`writeSvg` and `writePng` write through a temporary file (`common::replaceFile`): a failed write leaves the old file and no open channel (tclutils 0.69.0).

`parse` is **graph-only**: it returns a `tudiagram` model for the graph-like
Mermaid types and raises `{TCLUTILS TUFLOW UNSUPPORTED}` for every non-graph
type, including ones that `toSvg` / `toPng` draw. `toSvg` / `toPng` are the
**render facade**: they detect a non-graph block before `parse` is reached and
dispatch it to that family's renderer.

`writeSvg` and `writePng` pass their options through to `toSvg` and `toPng`.
A key the facade does not forward for that diagram is dropped.

### Graphs

`toPng` / `writePng` accept:

```text
-scale N       positive integer, default 1
               PNG supersample; the layout stays on the 6x8 metric
-fontfile F    TTF or OTF for the labels
```

`toSvg` / `writeSvg` take no options. `-scale` and `-fontfile` are dropped.
The SVG text uses the viewer's `monospace`.

`-fontfile` is stored on the model with `tudiagram::setMeta` and read when the
PNG is drawn. The file must exist; a missing path is
`{TCLUTILS TUDIAGRAM FONT}`. The outline font comes from the unbundled
`Glyphs` package. If that package is missing, the labels stay the 6x8 bitmap
and no error is raised. `-width`, `-height` and `-legend` are dropped on a
graph.

### Other families

`toSvg` and `toPng` both forward:

```text
-width N       canvas width in pixels
-height N      canvas height in pixels
-scale N       positive integer, default 1
-fontfile F    TTF or OTF, PNG only
-legend 0|1    pie only, default 1
```

`-scale` must be a positive integer. On PNG the canvas is `-width` times
`-scale` by `-height` times `-scale`, and the family uses the same number as
its drawing scale. On SVG the canvas stays at `-width` by `-height`.
`-fontfile` is ignored on SVG. On PNG a missing file is a `FONT` error from
that family (`{TCLUTILS TUPIE FONT}` and the same shape for the others). A
missing `Glyphs` package keeps the bitmap font.

Defaults when the option is left out:

```text
pie               -width 480  -height 320  -legend 1
xychart-beta      -width 520  -height 340
quadrantChart     -width 420  -height 420
journey           -width 600  -height 360
timeline          -width 640  -height 380
sankey            -width 700  -height 400
gantt             -width 800  -height 0     0 = 400, or more for many tasks
sequenceDiagram   -width 0    -height 0     0 = size from the layout
radar             -width 600  -height 600
treemap           -width 640  -height 400
packet            -width 640  -height 0     0 = height from the row count
kanban            -width 0    -height 0     0 = size from columns and cards
```

`sankey-beta`, `radar-beta`, `treemap-beta` and `packet-beta` use the same
defaults as the name without `-beta`. `-legend 0` draws the pie without the
legend column.

## Flowchart syntax (parse)

- Header `graph` or `flowchart` with an optional direction `LR`, `RL`, `TB`,
  `TD` (= `TB`) or `BT`; keyword and direction are case-insensitive
  (`FLOWCHART td`, `Graph LR`). Without a direction the graph is `LR`.
- Node ids are letters, digits and `_`, Unicode letters included
  (`Büro[Amt]` is the node `Büro`; 0.4).
- Nodes `A`, `A[box]`, `A(rounded)`, `A([stadium])`, `A((circle))`,
  `A{diamond}`, `A{{hexagon}}`, `A[(cylinder)]`, `A[[subroutine]]` (box).
- Edges `-->`, `---`, `-.->`, `-.-`, `==>`, `===`, `--o`, `--x`, with a label
  as `-->|text|`, `-- text -->`, `-. text .->` or `== text ==>`; chains
  `A --> B --> C`.
- `&` joins nodes on either side of an edge: `A & B --> C & D` gives one edge
  for every pair (`A->C`, `A->D`, `B->C`, `B->D`).
- `subgraph id [label]` ... `end` becomes a `tudiagram` group (nesting
  allowed); an edge to or from the subgraph id is dropped.
- `style`, `classDef`, `class`, `click`, `linkStyle` are skipped; `%%` starts
  a comment; `;` separates statements, but not inside a label in brackets,
  an edge label `|..|` or quotes (`A[Jörg;Büro]` is one node).

## Supported diagram types

Graph-like types go through `parse` and then `tudiagram`. They take the graph
options above:

```text
graph / flowchart       stateDiagram / stateDiagram-v2
requirementDiagram      erDiagram
classDiagram / classDiagram-v2
mindmap                 block-beta          gitGraph
architecture / architecture-beta
C4Context  C4Container  C4Component  C4Dynamic  C4Deployment
```

Non-graph types are drawn by `toSvg` / `toPng` only. `parse` raises
`{TCLUTILS TUFLOW UNSUPPORTED}` for them:

```text
pie                  xychart-beta         quadrantChart
journey              timeline             sankey / sankey-beta
gantt                sequenceDiagram      radar / radar-beta
treemap / treemap-beta
packet / packet-beta kanban
```

## Usage

```tcl
package require tclutils::tuflow
namespace import ::tclutils::tuflow::*

set graph {graph LR
    A[Start] --> B{Check}
    B -->|ok| C[Done]
    B -->|no| A
}
writePng $graph flow.png -scale 3
set svg [toSvg $graph]

set pie {pie title Result
    "pass" : 87
    "fail" : 3
}
writePng $pie pie.png -width 640 -height 400 -scale 2 -legend 1
```

[`examples/demo-tuflow.tcl`](../../examples/demo-tuflow.tcl) renders a
flowchart, a state diagram and a requirement diagram to SVG and PNG.
[`examples/demo-tudiagram.tcl`](../../examples/demo-tudiagram.tcl) builds the
model by hand. Both add `lib/tm` themselves.

## Notes

- `toSvg`/`toPng` on a graph are equivalent to
  `tudiagram::toSvg`/`toPng` of `parse`'s result; the facade just hides the
  dispatch. Keeping `parse` graph-only means existing callers that want the raw
  model are unaffected.
- New non-graph families are added in one place (a dispatch branch here plus a
  `tu<type>` module exposing `parse`/`toSvg`/`toPng`); consumers calling the
  facade need no change.
- Family modules for graphs: `tclutils::tudiagram`, `tclutils::tustate`,
  `tclutils::turequirement`, `tclutils::tuer`, `tclutils::tuclass`,
  `tclutils::tumindmap`, `tclutils::tuc4`, `tclutils::tublock`,
  `tclutils::tugit`, `tclutils::tuarchitecture`. Non-graph renderers:
  `tclutils::tupie`, `tclutils::tuxychart`, `tclutils::tuquadrant`,
  `tclutils::tujourney`, `tclutils::tutimeline`, `tclutils::tusankey`,
  `tclutils::tugantt`, `tclutils::tusequence`, `tclutils::turadar`,
  `tclutils::tutreemap`, `tclutils::tupacket`, `tclutils::tukanban`.
  Backends: `tclutils::tupngdraw`, `tclutils::tusvg`.

## Error codes

`-errorcode {TCLUTILS TUFLOW <REASON>}` — `UNSUPPORTED` (a diagram type with no
renderer), `EMPTY` (no nodes in a flowchart), `BADID` (a node id is not
letters, digits and `_`: a hyphen after an id is leftover junk, not an edge — e.g.
`Nwifi-3["SSID"]`). Errors from the dispatched family propagate with their own
code (`{TCLUTILS TUDIAGRAM ...}`, `{TCLUTILS TUPIE ...}`, and the same shape
for the other families). A `-scale` that is not a positive integer is that
family's `ARG` error. A `-fontfile` that names a missing file is its `FONT`
error.
