# tclutils::tudiagram

A pure-Tcl **node-edge graph renderer** for the `tuflow` diagram family. It
builds a small diagram model (a dict), runs a layered layout, and draws the
result to SVG or PNG with the pure-Tcl backends (`tclutils::tusvg` /
`tclutils::tupngdraw`). No Tk, no browser, no external rasteriser.

`tudiagram` is the renderer behind every *graph-shaped* Mermaid type that
`tclutils::tuflow` supports (flowchart/graph, stateDiagram, erDiagram,
classDiagram, requirementDiagram, mindmap, C4, …). Each of those parsers emits a
`tudiagram` model; the `tuflow` facade then calls `tudiagram::toSvg` /
`tudiagram::toPng`. Non-graph types (pie, xychart) own their own renderer and do
**not** go through `tudiagram`.

The render layer talks only to the congruent canvas protocol shared by `tusvg`
and `tupngdraw`: the same `render` proc emits SVG or PNG, the constructor is the
only difference. Box sizing uses the shared monospace text metric, so the layout
geometry is backend-independent and the SVG and PNG output stay congruent.

## Package

```tcl
package require tclutils::tudiagram 0.3
```

Depends only on `tclutils::common`. Building and laying out a model needs no
canvas; rendering needs a `tusvg` or `tupngdraw` object. The optional
`-fontfile` path additionally needs the third-party `Glyphs` package at render
time (lazy, unbundled).

## Model

The builders are **functional**: each returns the updated diagram dict, so the
idiom is `set d [tudiagram::addNode $d id -label X]`.

```tcl
{
    version 1
    meta  {title T direction LR theme default fontfile {} nodeGap 30 rankGap 70 padding 20}
    nodes {{id A label A shape box style {}} ...}
    edges {{from A to B label {} style solid arrow end} ...}
}
```

After `layout` each node additionally carries `x y width height` (top-left
origin, pixels), each edge carries a polyline `points` plus `back` (1 if the
edge was reversed to break a cycle), and `meta` carries `laid 1` and the overall
`width` / `height`.

## Commands

### Model builders

```tcl
::tclutils::tudiagram::create  ?-title T? ?-direction LR|TB|RL|BT? \
                               ?-theme name|dict? ?-fontfile F?      ;# -> diagram dict
::tclutils::tudiagram::setMeta d ?-key val ...?                      ;# -> diagram dict
::tclutils::tudiagram::addNode d id ?-label L? ?-shape S? ?-style D? ;# -> diagram dict
::tclutils::tudiagram::addEdge d from to ?-label L? ?-style E? ?-arrow A? \
                               ?-startMark M? ?-endMark M?              ;# -> diagram dict
```

`create` starts an empty diagram. `-direction` is the rank flow (default `LR`).
`-theme` is a theme name (see *Themes*) or an inline theme dict. `setMeta`
overrides any `meta` key after creation (e.g. `-direction TB`, `-nodeGap 40`);
it re-validates `direction`.

`addNode` adds a node; `id` must be unique. `-label` defaults to the id.
`-shape` is one of `box` (default), `rounded`, `dot`, `circle`, `stadium`,
`diamond`, `hexagon`, `cylinder`. `-style` is an optional per-node colour
override — a dict with any of the keys `fill`, `stroke`, `text` (6-digit hex),
e.g. `-style {fill #e3f2fd stroke #1565c0}`; absent keys fall back to the theme,
and a malformed or empty value is ignored (theme is used), so it is backward
compatible.

`addEdge` adds a directed edge between two node ids. `-style` is `solid`
(default), `dashed`, `dotted` or `thick` (a wider stroke, e.g. for a Mermaid
`==>` link). `-arrow` is `end` (default, head at the target), `none`, `both` or
`start`.

`-startMark` / `-endMark` add a crow's-foot cardinality mark at the `from` /
`to` end, independent of the arrow head. Value `M` is `none` (default),
`exactlyOne`, `zeroOrOne`, `oneOrMany` or `zeroOrMany` — each drawn as a
"max" symbol nearest the node (bar = one, crow's foot = many) plus a "min"
symbol toward the line (bar = one, ring = zero). An unknown value draws
nothing. `tclutils::tuer` uses these to render ER cardinality.

### Validation

```tcl
::tclutils::tudiagram::validate d        ;# -> list of problems ({} == valid)
```

Returns a list of `{REASON message}` problems: `EMPTY` if there are no nodes,
`NONODE` for any edge endpoint that is not a declared node id. An empty list
means the model is renderable. `validate` does not throw.

### Layout

```tcl
::tclutils::tudiagram::layout d          ;# -> diagram dict with geometry
```

Computes a layered layout for a DAG and returns a new dict with the geometry
fields described under *Model*. `render` / `toSvg` / `toPng` call `layout`
automatically when `meta.laid` is absent, so calling it directly is only needed
to inspect coordinates.

### Themes

```tcl
::tclutils::tudiagram::theme name        ;# -> theme dict
```

Resolves a theme name to its dict. Known names are `default`, `pipeline` and
`mono`. An unknown name returns `default`; an inline dict that carries a `fill`
key is merged over `default` and returned as-is. A theme dict has the keys
`fill stroke text edge font pad`.

### Rendering and output

```tcl
::tclutils::tudiagram::render   d canvas                  ;# draw onto a canvas object
::tclutils::tudiagram::toSvg    d ?-opt val ...?          ;# -> SVG string
::tclutils::tudiagram::toPng    d ?-scale N?              ;# -> PNG bytes
::tclutils::tudiagram::writeSvg d file ?-opt val ...?     ;# -> file (SVG)
::tclutils::tudiagram::writePng d file ?-scale N?         ;# -> file (PNG)
```

`render` draws the (already laid-out) model onto an existing canvas object — a
`tclutils::tusvg` or `tclutils::tupngdraw` instance — and is the low-level entry
point. The four `to*` / `write*` procs are the convenience wrappers: they
construct the right backend, call `render`, and return the bytes / write the
file.

## Render options

```text
-scale N      raster supersample factor, positive integer  (default 1; toPng/writePng only)
-fontfile F   real TTF/OTF for labels (raster backend)      (default: 6x8 bitmap font)
```

`-scale N` (raster only) renders at `N×` into an `N×`-sized canvas for a sharp,
supersampled PNG with the identical layout; the SVG backend ignores it. `-scale`
must be a positive integer.

`-fontfile` is passed to `create` (or `setMeta`). On the raster (PNG) backend
the labels are then drawn as real outlines via `tupngdraw fillcontours`, which
needs the unbundled `Glyphs` package (A. Buratti, permissive licence). The SVG
backend ignores `-fontfile` (it uses the viewer font), and the layout metric
stays 6x8 either way, so SVG and PNG geometry remain congruent.

## Usage

```tcl
package require tclutils::tudiagram
namespace import ::tclutils::tudiagram::*

set d [create -direction TB -theme pipeline -title "Build"]
set d [addNode $d src   -label "Source"]
set d [addNode $d build -label "Build"   -shape rounded]
set d [addNode $d ok    -label "OK"      -shape stadium -style {fill #e8f5e9 stroke #2e7d32}]
set d [addNode $d fail  -label "Fail"    -shape diamond -style {fill #ffebee stroke #c62828}]
set d [addEdge $d src   build]
set d [addEdge $d build ok   -label pass]
set d [addEdge $d build fail -label error -style dashed]

if {[set p [validate $d]] ne ""} { error "invalid diagram: $p" }

writePng $d build.png -scale 3       ;# crisp raster
writeSvg $d build.svg                ;# vector

set bytes [toPng $d -scale 2]
set svg   [toSvg $d]
```

Through the `tuflow` facade the same graph renders straight from Mermaid source,
without building the model by hand:

```tcl
package require tclutils::tuflow
set model [::tclutils::tuflow::parse $mermaidText]   ;# -> tudiagram model
::tclutils::tuflow::toPng $mermaidText -scale 3      ;# facade parses + renders
```

## Notes

- **Layout scope (v1):** layered layout for DAGs. Long edges (span > 1 rank) are
  routed through dummy lane nodes so they stay visible behind intermediate
  boxes; within-rank order is improved by a few barycentre sweeps to reduce
  crossings. Cycles are broken best-effort (a back-edge is drawn reversed and
  flagged `back 1`). Cross-axis placement is simple ordered stacking, so long
  chains can still wiggle slightly. **Self-loops are not drawn.**
- **Directions:** `LR` and `TB` are the primary flows; `RL` and `BT` are
  produced by mirroring the laid-out coordinates of `LR` / `TB`.
- **Shapes** are drawn with the primitive canvas operations only
  (rect/line/polygon/text); the supersample proxy exposes no native
  circle/ellipse, so round shapes are polygon approximations. This keeps every
  shape identical on the SVG and raster backends.
- **Fonts:** labels use the `tupngdraw` 6x8 bitmap font by default, which covers
  ASCII and the German umlauts (real codepoints `\u00xx`). With `-fontfile` on
  the raster backend a real outline font is used via `fillcontours` (lazy
  `Glyphs`, unbundled); a set-but-missing path is a hard error, a missing
  `Glyphs` package degrades silently to the bitmap font.
- **Companion modules:** `tclutils::tusvg` / `tclutils::tupngdraw` (backends),
  `tclutils::tuflow` (facade / dispatch), `tclutils::tupie` and
  `tclutils::tuxychart` (the non-graph renderers in the same family).

## Error codes

`-errorcode {TCLUTILS TUDIAGRAM <REASON>}`:

- `DUPID` — duplicate node id in `addNode`.
- `DIR` — `-direction` not one of `LR TB RL BT`.
- `ARG` — bad argument (unknown `-shape`, non-integer `-scale`, unknown render
  backend).
- `FONT` — a `-fontfile` path that does not exist (raster backend).
- `NONODE` / `EMPTY` — reported by `validate` (as list entries, not thrown):
  an edge endpoint with no matching node, or a model with no nodes.
