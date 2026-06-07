# tclutils::tupngdraw

A tiny pure-Tcl 2D drawing layer that renders to a PNG via `tclutils::tupng`.
No Tk and no external packages (TclOO is part of Tcl core). A surface is a
TclOO object whose command is the handle, in the spirit of `pdf4tcl` -- but a
PNG is a single surface, so there are no pages.

## API

```tcl
package require tclutils::tupngdraw

set p [::tclutils::tupngdraw::new -width 320 -height 200 -background white]
```

`new` options: `-width N` (default 100), `-height N` (default 100),
`-background COLOR` (default `white`).

Colours are accepted in several forms, interchangeably:
`red` (named), `#ff0000`, `FF0000`, `FF0000AA` (8-digit = with alpha),
`{r g b}` or `{r g b a}` (each 0..255). Alpha defaults to 255. Named colours:
black, white, red, green, lime, blue, yellow, cyan, magenta, gray/grey,
silver, orange, transparent/none.

Object methods:

```tcl
$p width                          ;# -> width in pixels
$p height                         ;# -> height in pixels
$p pixel x y                      ;# -> {r g b a} at x,y

$p setfill   COLOR                ;# fill colour for filled shapes
$p setstroke COLOR                ;# stroke colour for outlines/lines/pixels
$p setlinewidth N                 ;# stroke thickness (>=1)
$p setantialias 0|1               ;# antialiased strokes (default 1)
$p clear ?COLOR?                  ;# repaint whole surface (default: background)

$p setpixel x y ?-color COLOR?
$p line   x1 y1 x2 y2 ?-color COLOR? ?-width N?
$p rect   x1 y1 x2 y2 ?-fill 0|1? ?-outline 0|1? ?-join round|bevel|mitre? ?-color COLOR? ?-fillcolor COLOR?
$p circle cx cy r     ?-fill 0|1? ?-outline 0|1? ?-color COLOR? ?-fillcolor COLOR?
$p polygon {x0 y0 x1 y1 ...} ?-fill 0|1? ?-outline 0|1? ?-join round|bevel|mitre? ?-color COLOR? ?-fillcolor COLOR?
$p ellipse cx cy rx ry ?-fill 0|1? ?-outline 0|1? ?-color COLOR? ?-fillcolor COLOR?
$p arc cx cy r a0 a1 ?-style arc|pie|chord? ?-fill 0|1? ?-join round|bevel|mitre? ?-color C? ?-width N? ?-fillcolor C?
$p text x y string ?-color COLOR? ?-scale N? ?-spacing S?
$p textwidth string ?-scale N? ?-spacing S?      ;# -> pixel width

$p data  ?-compression 0..9? ?-filter best|none|sub|up|average|paeth?   ;# -> PNG bytes
$p write file ?-compression ...? ?-filter ...?                          ;# -> file
$p destroy
```

For the shapes, `-fill 1` fills the interior with the fill colour and (unless
`-outline 0`) draws the outline with the stroke colour and current line width.
`-color` overrides the stroke for that call; `-fillcolor` overrides the fill.

Drawing composites **source-over** (straight alpha), so a semi-transparent
fill blends with whatever is underneath; an opaque colour replaces it.

Outline strokes (line, rect/polygon/circle/ellipse outline, arc) are
**antialiased** by default and use a shared coverage buffer, so a thick
semi-transparent stroke stays alpha-correct: overlapping segments and corners
do not darken twice. Turn antialiasing off per surface with `setantialias 0`
or per call with `-aa 0` (crisp, pixel-exact). Fills (circle, ellipse, polygon,
pie) are antialiased too (supersampled). Outline corners use `-join`
`round` (default), `bevel` or `mitre` (mitre falls back to bevel past a
4x-width limit) on rect, polygon and arc.

```tcl
$p setfill {255 0 0}
$p rect 20 20 140 90 -fill 1
$p setfill {0 0 255 128}          ;# 50% blue, blends over the red
$p circle 110 70 40 -fill 1 -outline 0
$p write out.png -compression 9
$p destroy
```

## CLI

```bash
tclsh bin/tupngdraw.tcl demo out.png -width 320 -height 200
```

Renders a self-contained demo image (overlapping translucent discs, a filled
triangle, strokes) and prints the output path.

`arc` angles are in degrees, 0 = +x (east); the sweep runs from `a0` to `a1`
and, because y increases downward, appears clockwise on screen. `-style pie`
fills/closes through the centre, `chord` through the end-to-end chord, `arc`
is the bare curve. `text` uses an embedded 6x8 bitmap font (printable ASCII);
`-scale N` enlarges each font pixel to an NxN block.

## Scope and limits

Version 0.11 covers `setpixel`, `line`, `rect`, `circle`, `ellipse`, `polygon`
(even-odd scanline fill), `arc`/pie/chord and `text` (6x8 bitmap font), with
stroke/fill colour, line width, source-over alpha compositing and antialiased,
alpha-correct strokes. It is a 2D rasteriser: drawing is per-pixel
pure Tcl, well suited to labels, calendars, simple charts and preview
thumbnails, not to large photographic images.

The 6x8 font is an original, hand-authored bitmap set (95 ASCII glyphs plus the
German umlauts and eszett), embedded as glyph data and MIT-licensed like the
rest of the code. Antialiasing and alpha-correct thick strokes are implemented
(see above).

## Notes

The internal buffer is a flat list of bytes (R G B A per pixel) mutated in
place; on `write`/`data` it is packed once and handed to
`::tclutils::tupng::encodeRGBARaw`, the packed-bytes fast path added in
tupng 0.2. Rendering is deterministic: the same drawing produces byte-identical
PNGs across runs and across Tcl 8.6 and 9.x.

## Vector paths

`$p fillcontours {contour ...} ?-color C? ?-rule nonzero|evenodd? ?-aa 0|1?`
fills one shape made of one or more contours (each a flat `{x0 y0 x1 y1 ...}`),
antialiased and alpha-correct. The winding rule (`nonzero` default, or
`evenodd`) decides holes for nested contours -- the hook for rendering glyph
outlines or SVG-style paths.

## Glyphs

The embedded 6x8 font covers ASCII 32-126 plus the German letters a/o/u and A/O/U with diaeresis and the eszett. Unknown code points render blank.

## Compositing

`paste px py rgba sw sh ?-scale s?` alpha-composites a packed-RGBA block (e.g. from `tupng decode`) onto the image, nearest-neighbour scaled. Useful for layering existing PNGs and for image compositing (used by tkutils::tkcanvaspng).
