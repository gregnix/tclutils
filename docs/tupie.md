# tclutils::tupie

A Mermaid-style **pie chart** renderer for the `tuflow` diagram family. It parses
a Mermaid `pie` block into a small model and renders it to SVG or PNG with the
pure-Tcl drawing backends (`tclutils::tusvg` / `tclutils::tupngdraw`). No Tk, no
browser, no external rasteriser.

A pie chart is not a node-edge graph, so `tupie` does **not** go through
`tclutils::tudiagram`; it owns its own parse and draw step, exposing the same
`toSvg` / `toPng` shape `tudiagram` uses. That lets the `tclutils::tuflow` facade
treat every diagram family uniformly: `tuflow::toPng` / `tuflow::toSvg` detect a
`pie` block and dispatch here.

A slice is drawn as a filled polygon (centre plus arc-sampled rim points), so the
**same** routine renders identically on the raster and the SVG backend.

## Package

```tcl
package require tclutils::tupie 0.1
```

## Commands

```tcl
::tclutils::tupie::parse    text                          ;# -> model dict
::tclutils::tupie::toSvg     model ?-opt val ...?          ;# -> SVG string
::tclutils::tupie::toPng     model ?-opt val ...?          ;# -> PNG bytes
::tclutils::tupie::writeSvg  model file ?-opt val ...?     ;# -> file (SVG)
::tclutils::tupie::writePng  model file ?-opt val ...?     ;# -> file (PNG)
```

`parse` turns Mermaid `pie` source into a model dict with keys `title`
(string, may be empty), `showData` (`0`|`1`) and `slices` (a list of
`{label value}` pairs). The render commands take that model.

Render options (all optional):

```text
-width  N      diagram width in logical px        (default 480)
-height N      diagram height in logical px        (default 320)
-legend 0|1    show the legend column             (default 1)
-scale  N      raster scale, positive integer     (default 1; toPng only effect)
-fontfile F    real TTF/OTF for labels (raster)   (default: 6x8 bitmap font)
```

The SVG backend ignores `-scale` and `-fontfile` (it uses a fixed `monospace`
viewer font locked to the 6x8 metric). On the raster backend `-scale N`
multiplies the pixel dimensions and the font scale by `N`.

## Input grammar (Mermaid `pie` subset)

```text
pie                          %% header; the following are optional and in order
pie showData
pie title <text>
pie showData title <text>
title <text>                 %% alternatively on its own line
"<label>" : <value>          %% a slice; quotes optional, value int or float
%% ...                       %% comment, ignored
```

At least one slice is required and the values must sum to a positive number.

## Usage

```tcl
package require tclutils::tupie
namespace import ::tclutils::tupie::*

set src {pie showData title Browser share
    "Chrome"  : 64
    "Safari"  : 19
    "Edge"    : 5
    "Firefox" : 3
    "Other"   : 9
}

set m [parse $src]
writePng $m chart.png -scale 3       ;# crisp raster, with legend
writeSvg $m chart.svg                ;# vector

set bytes [toPng $m -legend 0]       ;# pie only, no legend
set svg   [toSvg $m]
```

Through the `tuflow` facade the same source renders without an explicit model:

```tcl
package require tclutils::tuflow
::tclutils::tuflow::toPng $src -scale 3      ;# facade detects the pie block
```

## Notes

- Slice colours come from a fixed qualitative palette (10 entries) that cycles
  when there are more slices than colours.
- A percentage label is drawn inside a slice only when the wedge is wide enough;
  the legend always carries label and percentage, plus the raw value when the
  source used `showData`.
- Labels use the `tupngdraw` 6x8 bitmap font by default, which covers ASCII and
  the German umlauts (real codepoints `\u00xx`). With `-fontfile` on the raster
  backend a real outline font is used via `fillcontours` (lazy `Glyphs`,
  unbundled); a set-but-missing path is a hard error, a missing `Glyphs` package
  degrades silently to the bitmap font.
- Companion modules: `tclutils::tupngdraw` and `tclutils::tusvg` (backends),
  `tclutils::tuflow` (facade / dispatch), `tclutils::tudiagram` (the node-edge
  graph renderer for the other Mermaid types).

## Error codes

`-errorcode {TCLUTILS TUPIE <REASON>}` — `EMPTY` (no slices), `VALUE` (values do
not sum to a positive number), `ARG` (bad render option, e.g. non-integer
`-scale`), `FONT` (a `-fontfile` path that does not exist).
