# tclutils::tujourney

A Mermaid-style **user journey** renderer for the `tuflow` diagram family. It
parses a Mermaid `journey` block into a small model and renders it to SVG or PNG
with the pure-Tcl drawing backends (`tclutils::tusvg` / `tclutils::tupngdraw`).
No Tk, no browser, no external rasteriser.

A journey is not a node-edge graph, so `tujourney` does **not** go through
`tclutils::tudiagram`; it owns its own parse and draw step, exposing the same
`toSvg` / `toPng` shape the other renderers use. That lets the
`tclutils::tuflow` facade treat every diagram family uniformly:
`tuflow::toPng` / `tuflow::toSvg` detect a `journey` block and dispatch here
(like `pie`, `xychart-beta` and `quadrantChart`).

The chart shows the tasks left-to-right in source order, a line through their
satisfaction scores, section bands across the top, the actors under each task
as coloured dots, and an actor legend.

## Package

```tcl
package require tclutils::tujourney 0.1
```

## Commands

```tcl
::tclutils::tujourney::parse    text                       ;# -> model dict
::tclutils::tujourney::toSvg    model ?-opt val ...?        ;# -> SVG string
::tclutils::tujourney::toPng    model ?-opt val ...?        ;# -> PNG bytes
::tclutils::tujourney::writeSvg model file ?-opt val ...?   ;# -> file (SVG)
::tclutils::tujourney::writePng model file ?-opt val ...?   ;# -> file (PNG)
```

`parse` turns Mermaid `journey` source into a model dict with keys `title`,
`tasks` (a list of `{name score actors section}`), `sections` (ordered unique
section names) and `actors` (ordered unique actor names). The render commands
take that model.

Render options (all optional):

```text
-width  N      chart width in logical px           (default 600)
-height N      chart height in logical px          (default 360)
-scale  N      raster scale, positive integer      (default 1; toPng only)
-fontfile F    real TTF/OTF for labels (raster)    (default: 6x8 bitmap font)
```

The SVG backend ignores `-scale` and `-fontfile` (it uses a fixed `monospace`
viewer font locked to the 6x8 metric). On the raster backend `-scale N`
multiplies the pixel dimensions and the font scale by `N`.

## Input grammar (Mermaid `journey` subset)

```text
journey                            %% header
title <text>                       %% chart title
section <name>                     %% starts a section
<task>: <score>: <actor>, <actor>  %% a task with a 1..5 score and actors
<task>: <score>                    %% actors are optional
%% ...                             %% comment, ignored
```

At least one task is required. Tasks listed before any `section` keep an empty
section.

## Usage

```tcl
package require tclutils::tujourney
namespace import ::tclutils::tujourney::*

set src {journey
    title My working day
    section Go to work
      Make tea: 5: Me
      Go upstairs: 3: Me
      Do work: 1: Me, Cat
    section Go home
      Go downstairs: 5: Me
      Sit down: 3: Me
}

set m [parse $src]
writePng $m journey.png -scale 3
writeSvg $m journey.svg
```

Through the `tuflow` facade the same source renders without an explicit model:

```tcl
package require tclutils::tuflow
::tclutils::tuflow::toPng $src -scale 3      ;# facade detects the journey block
```

## Notes

- Actor colours come from a fixed qualitative palette (10 entries) that cycles;
  a task's score point is coloured by its first actor, and every actor of a task
  is shown as a small dot under the task name. Section bands cycle through a
  light tint palette.
- v1 limitations (honest): task names are drawn horizontally (not rotated) and
  may crowd when long or numerous; scores are plotted on a `0..max(5,data)`
  axis; a section is a contiguous run of tasks (as Mermaid emits them).
- Labels use the `tupngdraw` 6x8 bitmap font by default. With `-fontfile` on the
  raster backend a real outline font is used via `fillcontours` (lazy `Glyphs`,
  unbundled); a set-but-missing path is a hard error, a missing `Glyphs` package
  degrades silently to the bitmap font.
- Companion modules: `tclutils::tupngdraw` and `tclutils::tusvg` (backends),
  `tclutils::tuflow` (facade / dispatch), `tclutils::tudiagram` (the node-edge
  graph renderer for the other Mermaid types).

## Error codes

`-errorcode {TCLUTILS TUJOURNEY <REASON>}` — `EMPTY` (no tasks), `ARG` (bad
render option, e.g. non-integer `-scale`), `FONT` (a `-fontfile` path that does
not exist).
