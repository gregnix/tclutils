# tclutils::tutreemap

Parses a Mermaid `treemap-beta` block and renders it as a **squarified treemap**
-- area-proportional nested rectangles -- natively (SVG or PNG) through the
pure-Tcl engine. A self-contained 2D renderer in the `tclutils::tuflow` family
(like `tupie` / `tukanban` / `tupacket`); normally you call `tuflow::toSvg` /
`tuflow::toPng`, which dispatch here. A treemap is a hierarchical area chart, not
a node-edge graph, so it does **not** go through `tudiagram`.

## Package

```tcl
package require tclutils::tutreemap 0.1
```

## Commands

```tcl
::tclutils::tutreemap::parse text                          ;# -> nested tree dict
::tclutils::tutreemap::toSvg  model ?-width W? ?-height H? ?-fontfile f? ?-scale n?
::tclutils::tutreemap::toPng  model ?...?                  ;# -> PNG bytes
::tclutils::tutreemap::writeSvg model file ?...?
::tclutils::tutreemap::writePng model file ?...?
```

`parse` returns the root node `{name "" value <total> children {...}}`; each child
is the same shape. A branch's `value` is the sum of its children; a leaf's is the
number it was given.

## Supported syntax (Mermaid subset)

```text
treemap-beta
"Section"                -> a branch (parent); value = sum of children
    "Leaf": <value>      -> a leaf with a numeric value
        ...              -> deeper indentation = deeper nesting
```

- The header is `treemap-beta` (or bare `treemap`).
- Indentation defines the hierarchy; a node with a value and no deeper-indented
  lines is a leaf, otherwise a branch.
- A `:::class` styling tag and `classDef` / `style` lines are parsed off and
  **ignored** (v1). Blank lines and `%%` comments are ignored.
- Quotes around names are recommended (Mermaid style); a bare `Name: value` /
  `Name` is tolerated.

## Layout

Tiling uses the **squarify** algorithm (Bruls/Huizing/van Wijk): children are
sorted by value and packed into rows so each cell stays close to square, which
makes areas easy to compare. Each branch below the root draws a header bar with
its name; leaves show name + value when the cell is large enough. Colours come
from a fixed palette assigned per top-level section and lightened with depth, so
the hierarchy reads at a glance; nested branches get their own darker header bar.

## v1 limitations (honest)

- Styling (`:::class`, `classDef`, theme, `valueFormat`) is ignored.
- Labels are clipped to their cell, not wrapped or shrunk; very small cells show
  no label.
- Negative values are dropped (a treemap needs non-negative areas).
- A node given a value *and* children is treated as a branch (the children's sum
  wins over the explicit value).

## Options

`-width` (default 640), `-height` (default 400), `-fontfile` (a TTF for real-font
labels via `Glyphs`; PNG only -- otherwise the built-in 6x8 bitmap font with
German umlauts via real codepoints), `-scale` (positive integer; enlarges the PNG
canvas, SVG ignores it).

## Usage

```tcl
package require tclutils::tutreemap
set src {treemap-beta
    "Annual Budget"
        "Operations"
            "Salaries": 700000
            "Equipment": 200000
        "Marketing"
            "Advertising": 400000}
::tclutils::tutreemap::writePng [::tclutils::tutreemap::parse $src] budget.png -scale 3
```

In Markdown, `treemap-beta` rides on the ```` ```mermaid ```` fence, so docir's
raster sinks render it through `tuflow::toPng`; no docir change is needed.

## Notes

- Companion: `tclutils::tusvg` / `tclutils::tupngdraw` (canvas),
  `tclutils::tuflow` (dispatch).
- Cells, headers and labels use only rect/text primitives, so SVG and PNG stay
  congruent.
- `tuflow::parse` rejects `treemap-beta` with `{TCLUTILS TUFLOW UNSUPPORTED}` (it
  is not a node-edge graph); the facade `toSvg`/`toPng` is the render path,
  exactly as for `pie` / `kanban` / `packet`.

## Error codes

`-errorcode {TCLUTILS TUTREEMAP <REASON>}` -- `EMPTY` (no header / no nodes),
`VALUE` (non-numeric value), `ARG` (bad `-scale`), `FONT` (font file not found).
