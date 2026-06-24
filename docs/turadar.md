# tclutils::turadar

Parses a Mermaid `radar-beta` block and renders it as a **radar / spider chart**
natively (SVG or PNG) through the pure-Tcl engine. A self-contained 2D renderer
in the `tclutils::tuflow` family (like `tupie` / `tukanban` / `tupacket` /
`tutreemap`); normally you call `tuflow::toSvg` / `tuflow::toPng`, which dispatch
here. A radar chart is a polar plot, not a node-edge graph, so it does **not** go
through `tudiagram`.

## Package

```tcl
package require tclutils::turadar 0.1
```

## Commands

```tcl
::tclutils::turadar::parse text                          ;# -> radar model dict
::tclutils::turadar::toSvg  model ?-width W? ?-height H? ?-fontfile f? ?-scale n?
::tclutils::turadar::toPng  model ?...?                  ;# -> PNG bytes
::tclutils::turadar::writeSvg model file ?...?
::tclutils::turadar::writePng model file ?...?
```

## Supported syntax (Mermaid subset)

```text
radar-beta
title <text>                     -> optional title
axis A, B, C                     -> axes (bare ids; or id["Label"])
axis m["Math"], s["Science"]     -> may repeat; ids accumulate in order
curve id["Label"]{v1, v2, ...}   -> a data series, values in axis order
curve id{ ax2: 30, ax1: 20 }     -> key-value form (by axis id)
max <n> / min <n>                -> value scale (default min 0, max = data max)
ticks <n>                        -> number of graticule rings (default 5)
graticule circle|polygon         -> ring shape (default circle)
showLegend true|false            -> legend toggle (default: on if labelled)
```

- The header is `radar-beta` (or bare `radar`).
- `axis` lines accumulate; each axis is a bare id or `id["Label"]`.
- A `curve`'s values are positional (axis order) or key-value (`axisId: value`);
  missing axes default to 0, extra values are ignored.
- `min`/`max` set the scale; `max` defaults to the largest data value, `min` to 0.
- Blank lines and `%%` comments are ignored. Unknown config lines are ignored.

## Layout

Each axis radiates from the centre at 360/N spacing, with the first axis at the
top and the rest clockwise. `ticks` graticule rings (concentric `circle`s or
`polygon`s) mark the scale, with value labels along the top axis. Each curve
plots one point per axis at radius proportional to `(value-min)/(max-min)`
(clamped to the rim) and connects them into a closed polygon with a translucent
area fill, a solid outline and vertex dots, coloured from a fixed palette. An
optional legend lists the curves.

## v1 limitations (honest)

- Curves are straight-edged polygons -- no Catmull-Rom spline smoothing. Each
  gets a translucent area fill (overlaps blend) plus a solid outline and dots.
- One curve per `curve` line (Mermaid's comma-joined multi-curve lines are not
  split).
- Theme / config / `cScale` styling is ignored.
- Needs at least 3 axes (a polygon needs >= 3 points) -- fewer is an `AXES` error.

## Options

`-width` / `-height` (default 600 each), `-fontfile` (a TTF for real-font labels
via `Glyphs`; PNG only -- otherwise the built-in 6x8 bitmap font with German
umlauts via real codepoints), `-scale` (positive integer; enlarges the PNG
canvas, SVG ignores it).

## Usage

```tcl
package require tclutils::turadar
set src {radar-beta
    title Skill Assessment
    axis Communication, Coding, Design, Testing
    curve a["Alice"]{80, 90, 60, 75}
    curve b["Bob"]{70, 65, 85, 80}
    max 100
    ticks 5
    graticule polygon}
::tclutils::turadar::writePng [::tclutils::turadar::parse $src] skills.png -scale 3
```

In Markdown, `radar-beta` rides on the ```` ```mermaid ```` fence, so docir's
raster sinks render it through `tuflow::toPng`; no docir change is needed.

## Notes

- Companion: `tclutils::tusvg` / `tclutils::tupngdraw` (canvas; both provide the
  congruent `polygon` / `circle` / `line` primitives this uses),
  `tclutils::tuflow` (dispatch).
- Spokes, rings, curves and dots use only line/polygon/circle primitives, so SVG
  and PNG stay congruent.
- `tuflow::parse` rejects `radar-beta` with `{TCLUTILS TUFLOW UNSUPPORTED}` (it
  is not a node-edge graph); the facade `toSvg`/`toPng` is the render path,
  exactly as for `pie` / `kanban` / `packet` / `treemap`.

## Error codes

`-errorcode {TCLUTILS TURADAR <REASON>}` -- `EMPTY` (no header / no curves),
`AXES` (fewer than 3 axes), `VALUE` (non-numeric value), `ARG` (bad `-scale`),
`FONT` (font file not found).
