# tclutils::tuxychart

A Mermaid-style **xy chart** (bar / line) renderer for the `tuflow` diagram
family. It parses a Mermaid `xychart-beta` block into a small model and renders
it to SVG or PNG with the pure-Tcl drawing backends (`tclutils::tusvg` /
`tclutils::tupngdraw`). No Tk, no browser, no external rasteriser.

An xy chart is not a node-edge graph, so `tuxychart` does **not** go through
`tclutils::tudiagram`; it owns its own parse and draw step, exposing the same
`toSvg` / `toPng` shape the other renderers use. That lets the
`tclutils::tuflow` facade treat every diagram family uniformly:
`tuflow::toPng` / `tuflow::toSvg` detect an `xychart-beta` block and dispatch
here (like `pie`).

Axes, gridlines, bars and line segments are drawn with the same routine on both
backends, so the SVG and the raster output stay congruent.

## Package

```tcl
package require tclutils::tuxychart 0.1
```

## Commands

```tcl
::tclutils::tuxychart::parse    text                       ;# -> model dict
::tclutils::tuxychart::toSvg    model ?-opt val ...?        ;# -> SVG string
::tclutils::tuxychart::toPng    model ?-opt val ...?        ;# -> PNG bytes
::tclutils::tuxychart::writeSvg model file ?-opt val ...?   ;# -> file (SVG)
::tclutils::tuxychart::writePng model file ?-opt val ...?   ;# -> file (PNG)
```

`parse` turns Mermaid `xychart-beta` source into a model dict with keys `title`,
`orientation` (`vertical`|`horizontal`), `xtitle`, `categories` (a list of axis
labels), `xnumeric`/`xmin`/`xmax` (for a numeric x-axis), `ytitle`, `yauto`
(`0`|`1`), `ymin`/`ymax`, and `series` (a list of `{type bar|line values {...}}`
dicts). The render commands take that model.

Render options (all optional):

```text
-width  N      chart width in logical px           (default 520)
-height N      chart height in logical px          (default 340)
-scale  N      raster scale, positive integer      (default 1; toPng only)
-fontfile F    real TTF/OTF for labels (raster)    (default: 6x8 bitmap font)
```

The SVG backend ignores `-scale` and `-fontfile` (it uses a fixed `monospace`
viewer font locked to the 6x8 metric). On the raster backend `-scale N`
multiplies the pixel dimensions and the font scale by `N`.

## Input grammar (Mermaid `xychart-beta` subset)

```text
xychart-beta                       %% header (a trailing `horizontal` is parsed)
title "<text>"                     %% chart title
x-axis "<title>"? [a, b, c, ...]   %% categorical labels
x-axis "<title>"? <min> --> <max>  %% numeric axis (labels synthesised)
y-axis "<title>"? (<min> --> <max>)?   %% axis title and/or explicit range
bar  [v1, v2, ...]                 %% a bar series   (multiple allowed)
line [v1, v2, ...]                 %% a line series  (multiple allowed)
%% ...                             %% comment, ignored
```

At least one `bar` or `line` series is required. Without an explicit `y-axis`
range the scale is taken automatically from the data (zero-based, rounded up to
a nice 1/2/5 ceiling).

## Usage

```tcl
package require tclutils::tuxychart
namespace import ::tclutils::tuxychart::*

set src {xychart-beta
    title "Sales Revenue"
    x-axis [jan, feb, mar, apr, may]
    y-axis "Revenue ($)" 0 --> 11000
    bar  [5000, 6000, 7500, 8200, 9500]
    line [4000, 5000, 6800, 9000, 10500]
}

set m [parse $src]
writePng $m chart.png -scale 3       ;# crisp raster
writeSvg $m chart.svg                ;# vector
```

Through the `tuflow` facade the same source renders without an explicit model:

```tcl
package require tclutils::tuflow
::tclutils::tuflow::toPng $src -scale 3      ;# facade detects the xychart block
```

## Notes

- Series colours come from a fixed qualitative palette (10 entries) that cycles
  when there are more series than colours; a legend is drawn when more than one
  series is present.
- Multiple `bar` series share each category slot side by side; `line` series are
  drawn as connected segments with small square markers.
- v1 limitations (honest): only the vertical orientation is drawn (a trailing
  `horizontal` is recorded but ignored); the y-axis title is placed horizontally,
  not rotated.
- Labels use the `tupngdraw` 6x8 bitmap font by default. With `-fontfile` on the
  raster backend a real outline font is used via `fillcontours` (lazy `Glyphs`,
  unbundled); a set-but-missing path is a hard error, a missing `Glyphs` package
  degrades silently to the bitmap font.
- Companion modules: `tclutils::tupngdraw` and `tclutils::tusvg` (backends),
  `tclutils::tuflow` (facade / dispatch), `tclutils::tudiagram` (the node-edge
  graph renderer for the other Mermaid types).

## Error codes

`-errorcode {TCLUTILS TUXYCHART <REASON>}` — `EMPTY` (no series), `VALUE`
(non-numeric value in a series), `ARG` (bad render option, e.g. non-integer
`-scale`), `FONT` (a `-fontfile` path that does not exist).
