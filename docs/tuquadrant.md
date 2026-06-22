# tclutils::tuquadrant

A Mermaid-style **quadrant chart** renderer for the `tuflow` diagram family. It
parses a Mermaid `quadrantChart` block into a small model and renders it to SVG
or PNG with the pure-Tcl drawing backends (`tclutils::tusvg` /
`tclutils::tupngdraw`). No Tk, no browser, no external rasteriser.

A quadrant chart is not a node-edge graph, so `tuquadrant` does **not** go
through `tclutils::tudiagram`; it owns its own parse and draw step, exposing the
same `toSvg` / `toPng` shape the other renderers use. That lets the
`tclutils::tuflow` facade treat every diagram family uniformly:
`tuflow::toPng` / `tuflow::toSvg` detect a `quadrantChart` block and dispatch
here (like `pie` and `xychart-beta`).

The plot is a unit square split into four tinted quadrants; data points are
placed at their normalised `0..1` coordinates with the same routine on both
backends, so the SVG and the raster output stay congruent.

## Package

```tcl
package require tclutils::tuquadrant 0.1
```

## Commands

```tcl
::tclutils::tuquadrant::parse    text                       ;# -> model dict
::tclutils::tuquadrant::toSvg    model ?-opt val ...?        ;# -> SVG string
::tclutils::tuquadrant::toPng    model ?-opt val ...?        ;# -> PNG bytes
::tclutils::tuquadrant::writeSvg model file ?-opt val ...?   ;# -> file (SVG)
::tclutils::tuquadrant::writePng model file ?-opt val ...?   ;# -> file (PNG)
```

`parse` turns Mermaid `quadrantChart` source into a model dict with keys
`title`, `xleft`/`xright`, `ybottom`/`ytop`, `q1`..`q4` (quadrant labels) and
`points` (a list of `{name x y}` with `x`,`y` in `0..1`). The render commands
take that model.

Render options (all optional):

```text
-width  N      chart width in logical px           (default 420)
-height N      chart height in logical px          (default 420)
-scale  N      raster scale, positive integer      (default 1; toPng only)
-fontfile F    real TTF/OTF for labels (raster)    (default: 6x8 bitmap font)
```

The SVG backend ignores `-scale` and `-fontfile` (it uses a fixed `monospace`
viewer font locked to the 6x8 metric). On the raster backend `-scale N`
multiplies the pixel dimensions and the font scale by `N`.

## Input grammar (Mermaid `quadrantChart` subset)

```text
quadrantChart                      %% header
title <text>                       %% chart title
x-axis <left> --> <right>          %% x-axis end labels (axis is 0..1)
y-axis <bottom> --> <top>          %% y-axis end labels (axis is 0..1)
quadrant-1 <text> ... quadrant-4   %% 1=top-right, 2=top-left,
                                   %% 3=bottom-left, 4=bottom-right
<Point Name>: [x, y]               %% point at normalised 0..1 coords
%% ...                             %% comment, ignored
```

Any of title, axes, quadrant labels or points counts as content; a completely
empty source is an error. A trailing style hint after a point
(`radius:`, `color:`, ...) is accepted and ignored.

## Usage

```tcl
package require tclutils::tuquadrant
namespace import ::tclutils::tuquadrant::*

set src {quadrantChart
    title Reach and engagement of campaigns
    x-axis Low Reach --> High Reach
    y-axis Low Engagement --> High Engagement
    quadrant-1 We should expand
    quadrant-2 Need to promote
    quadrant-3 Re-evaluate
    quadrant-4 May be improved
    Campaign A: [0.3, 0.6]
    Campaign B: [0.45, 0.23]
    Campaign C: [0.57, 0.69]
}

set m [parse $src]
writePng $m quad.png -scale 3
writeSvg $m quad.svg
```

Through the `tuflow` facade the same source renders without an explicit model:

```tcl
package require tclutils::tuflow
::tclutils::tuflow::toPng $src -scale 3      ;# facade detects the quadrantChart block
```

## Notes

- Point colours come from a fixed qualitative palette (10 entries) that cycles
  when there are more points than colours.
- v1 limitations (honest): per-point style hints (`radius:`, `color:`, ...) are
  ignored; the y-axis end labels are placed horizontally in the left margin, not
  rotated; coordinates outside `0..1` are clamped.
- Labels use the `tupngdraw` 6x8 bitmap font by default. With `-fontfile` on the
  raster backend a real outline font is used via `fillcontours` (lazy `Glyphs`,
  unbundled); a set-but-missing path is a hard error, a missing `Glyphs` package
  degrades silently to the bitmap font.
- Companion modules: `tclutils::tupngdraw` and `tclutils::tusvg` (backends),
  `tclutils::tuflow` (facade / dispatch), `tclutils::tudiagram` (the node-edge
  graph renderer for the other Mermaid types).

## Error codes

`-errorcode {TCLUTILS TUQUADRANT <REASON>}` — `EMPTY` (no content at all), `ARG`
(bad render option, e.g. non-integer `-scale`), `FONT` (a `-fontfile` path that
does not exist).
