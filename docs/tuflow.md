# tclutils::tuflow

The front end of the `tuflow` diagram family: it parses a Mermaid / flowchart
source block and renders it to SVG or PNG. It is the single entry point a
consumer (e.g. a documentation renderer) calls; it detects the diagram kind and
dispatches to the right family module, so the caller never has to know whether a
block is a graph, a class diagram or a pie chart.

Everything is pure Tcl: graphs go through `tclutils::tudiagram` (a node-edge
layout over the `tclutils::tupngdraw` / `tclutils::tusvg` backends), pie charts
through `tclutils::tupie`. No Tk, no browser, no external rasteriser.

## Package

```tcl
package require tclutils::tuflow 0.2
```

## Commands

```tcl
::tclutils::tuflow::parse    text                       ;# -> tudiagram model (graphs only)
::tclutils::tuflow::toSvg     text ?-opt val ...?        ;# -> SVG string
::tclutils::tuflow::toPng     text ?-opt val ...?        ;# -> PNG bytes
::tclutils::tuflow::writeSvg  text file ?-opt val ...?   ;# -> file (SVG)
::tclutils::tuflow::writePng  text file ?-opt val ...?   ;# -> file (PNG)
```

`parse` is **graph-only**: it returns a `tudiagram` model for the graph-like
Mermaid types and raises `{TCLUTILS TUFLOW UNSUPPORTED}` for everything else.
`toSvg` / `toPng` are the **render facade**: they render *any* supported family,
detecting non-graph blocks (currently `pie`) before `parse` is reached and
dispatching them to their own renderer.

Render options are forwarded to the family that handles the block; an option a
family does not understand is ignored. Common ones:

```text
-fontfile F    real TTF/OTF for labels on the raster backend (graph + pie)
-scale  N      raster scale, positive integer (toPng)
-width  N      pie width   (pie only)
-height N      pie height  (pie only)
-legend 0|1    pie legend  (pie only)
```

For the graph path `-fontfile` is applied to the `tudiagram` model via
`setMeta -fontfile` before rasterising; the SVG backend uses its fixed
`monospace` viewer font.

## Supported diagram types

Graph-like (rendered as node-edge diagrams via `tudiagram`):

```text
graph / flowchart    stateDiagram    requirementDiagram    erDiagram    classDiagram
```

Non-graph (own renderer):

```text
pie                  -> tclutils::tupie
```

Other Mermaid types (`sequenceDiagram`, `gantt`, `journey`, `gitGraph`, ...) are
not supported and raise `{TCLUTILS TUFLOW UNSUPPORTED}`; a consumer typically
falls back to showing the source as a code block.

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
writePng $pie pie.png -scale 3       ;# same facade, dispatched to tupie
```

## Notes

- `toSvg`/`toPng` on a graph are equivalent to
  `tudiagram::toSvg`/`toPng` of `parse`'s result; the facade just hides the
  dispatch. Keeping `parse` graph-only means existing callers that want the raw
  model are unaffected.
- New non-graph families are added in one place (a dispatch branch here plus a
  `tu<type>` module exposing `parse`/`toSvg`/`toPng`); consumers calling the
  facade need no change.
- Family modules: `tclutils::tudiagram` (graphs), `tclutils::tustate`,
  `tclutils::turequirement`, `tclutils::tuer`, `tclutils::tuclass` (graph-type
  parsers), `tclutils::tupie` (pie). Backends: `tclutils::tupngdraw`,
  `tclutils::tusvg`.

## Error codes

`-errorcode {TCLUTILS TUFLOW <REASON>}` — `UNSUPPORTED` (a diagram type with no
renderer). Errors from the dispatched family propagate with their own code
(`{TCLUTILS TUDIAGRAM ...}`, `{TCLUTILS TUPIE ...}`).
