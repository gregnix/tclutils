# tclutils::tutimeline

A Mermaid-style **timeline** renderer for the `tuflow` diagram family. It parses
a Mermaid `timeline` block into a small model and renders it to SVG or PNG with
the pure-Tcl drawing backends (`tclutils::tusvg` / `tclutils::tupngdraw`). No Tk,
no browser, no external rasteriser.

A timeline is not a node-edge graph, so `tutimeline` does **not** go through
`tclutils::tudiagram`; it owns its own parse and draw step, exposing the same
`toSvg` / `toPng` shape the other renderers use. That lets the
`tclutils::tuflow` facade treat every diagram family uniformly:
`tuflow::toPng` / `tuflow::toSvg` detect a `timeline` block and dispatch here
(like `pie`, `xychart-beta`, `quadrantChart` and `journey`).

The chart is drawn horizontally: a time axis with the period labels below it,
each period's events stacked as boxes above it, and sections as coloured bands
across the top.

## Package

```tcl
package require tclutils::tutimeline 0.1
```

## Commands

```tcl
::tclutils::tutimeline::parse    text                       ;# -> model dict
::tclutils::tutimeline::toSvg    model ?-opt val ...?        ;# -> SVG string
::tclutils::tutimeline::toPng    model ?-opt val ...?        ;# -> PNG bytes
::tclutils::tutimeline::writeSvg model file ?-opt val ...?   ;# -> file (SVG)
::tclutils::tutimeline::writePng model file ?-opt val ...?   ;# -> file (PNG)
```

`parse` turns Mermaid `timeline` source into a model dict with keys `title`,
`periods` (a list of `{time events section}`, `events` a list) and `sections`
(ordered unique section names). The render commands take that model.

Render options (all optional):

```text
-width  N      chart width in logical px           (default 640)
-height N      chart height in logical px          (default 380)
-scale  N      raster scale, positive integer      (default 1; toPng only)
-fontfile F    real TTF/OTF for labels (raster)    (default: 6x8 bitmap font)
```

The SVG backend ignores `-scale` and `-fontfile` (it uses a fixed `monospace`
viewer font locked to the 6x8 metric). On the raster backend `-scale N`
multiplies the pixel dimensions and the font scale by `N`.

## Input grammar (Mermaid `timeline` subset)

```text
timeline                           %% header
title <text>                       %% chart title
section <name>                     %% starts a section
<time> : <event> : <event> ...     %% a time period with one or more events
        : <event>                  %% continuation: more events for the
                                   %% previous period
%% ...                             %% comment, ignored
```

At least one time period is required. Periods listed before any `section` keep
an empty section.

## Usage

```tcl
package require tclutils::tutimeline
namespace import ::tclutils::tutimeline::*

set src {timeline
    title History of Social Media
    2002 : LinkedIn
    2004 : Facebook : Google
    2005 : YouTube
    section 2010s
      2010 : Instagram
      2011 : Snapchat : WhatsApp
}

set m [parse $src]
writePng $m timeline.png -scale 3
writeSvg $m timeline.svg
```

Through the `tuflow` facade the same source renders without an explicit model:

```tcl
package require tclutils::tuflow
::tclutils::tuflow::toPng $src -scale 3      ;# facade detects the timeline block
```

## Notes

- Each period (and its event boxes) is coloured from a light tint palette,
  grouped per section so a section reads as one colour; an empty leading section
  cycles by period.
- v1 limitations (honest): horizontal layout only; long event text or many
  periods may crowd or clip (no wrapping or rotation); a section is a contiguous
  run of periods (as Mermaid emits them); events that overflow the available
  height are dropped from the top.
- Labels use the `tupngdraw` 6x8 bitmap font by default. With `-fontfile` on the
  raster backend a real outline font is used via `fillcontours` (lazy `Glyphs`,
  unbundled); a set-but-missing path is a hard error, a missing `Glyphs` package
  degrades silently to the bitmap font.
- Companion modules: `tclutils::tupngdraw` and `tclutils::tusvg` (backends),
  `tclutils::tuflow` (facade / dispatch), `tclutils::tudiagram` (the node-edge
  graph renderer for the other Mermaid types).

## Error codes

`-errorcode {TCLUTILS TUTIMELINE <REASON>}` — `EMPTY` (no periods), `ARG` (bad
render option, e.g. non-integer `-scale`), `FONT` (a `-fontfile` path that does
not exist).
