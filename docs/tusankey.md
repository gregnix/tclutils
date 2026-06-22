# tclutils::tusankey

Parses a Mermaid `sankey-beta` block and renders it natively (SVG or PNG)
through the pure-Tcl engine. A self-contained 2D renderer in the
`tclutils::tuflow` family (like `tupie` / `tuxychart`); normally you call
`tuflow::toSvg` / `tuflow::toPng`, which dispatch here.

## Package

```tcl
package require tclutils::tusankey 0.1
```

## Commands

```tcl
::tclutils::tusankey::parse text                          ;# -> sankey model dict
::tclutils::tusankey::toSvg  model ?-width W? ?-height H? ?-fontfile f? ?-scale n?
::tclutils::tusankey::toPng  model ?...?                  ;# -> PNG bytes
::tclutils::tusankey::writeSvg model file ?...?
::tclutils::tusankey::writePng model file ?...?
```

## Supported syntax (Mermaid subset)

```text
sankey-beta
source,target,value      -> one flow per line (CSV, exactly 3 columns)
```

- The header line is `sankey-beta` (or `sankey`); the data rows follow.
- A node name containing a comma is wrapped in double quotes; a literal double
  quote inside is written as a pair (`""`).
- Blank lines and `%%` comments are ignored. Values must be positive numbers.
- Nodes appear in first-seen order.

## Layout (v1)

Nodes are placed in columns by longest-path rank from the sources; each node's
height is proportional to `max(inflow, outflow)`. Links are drawn as smooth
bands whose width is proportional to the value, stacked at each node in link
order and coloured after the source node (Mermaid `linkColor: source`). Cycles
are handled best-effort (the rank iteration is bounded). v1 does not minimise
band crossings or honour Mermaid's `linkColor` / `nodeAlignment` configuration.

## Options

`-width` / `-height` (default 700 x 400), `-fontfile` (a TTF for real-font
labels via `Glyphs`; PNG only -- otherwise the built-in bitmap font), `-scale`
(positive integer; enlarges the PNG canvas, SVG ignores it).

## Usage

```tcl
package require tclutils::tusankey
set src {sankey-beta
Coal,Electricity,40
Gas,Electricity,25
Electricity,Residential,30
Electricity,Industry,35}
::tclutils::tusankey::writePng [::tclutils::tusankey::parse $src] energy.png -scale 2
```

## Notes

- Companion: `tclutils::tusvg` / `tclutils::tupngdraw` (canvas),
  `tclutils::tuflow` (dispatch).
- Bands and nodes use only rect/polygon primitives, so SVG and PNG stay
  congruent.

## Error codes

`-errorcode {TCLUTILS TUSANKEY <REASON>}` -- `EMPTY` (no flows), `ARG` (bad
`-scale`), `FONT` (font file not found).
