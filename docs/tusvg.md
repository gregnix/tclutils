# tclutils::tusvg

A pure-Tcl **SVG generator** -- no Tk, no external packages. Build a document as
a dict, add shapes/paths/text/gradients/groups, and render to a string or file.
Ships a library of ~110 named toolbar icons. It complements the `tupng`
encoders: `tusvg` is the vector counterpart.

## Document

```tcl
set svg [tusvg::create width height ?-viewBox "x y w h"? ?-id name?]
set out [tusvg::toString $svg]              ;# SVG text
tusvg::write $svg file.svg                  ;# UTF-8 file
```

## Elements (append to the document variable)

```tcl
tusvg::rect     svg x y w h     ?-fill c? ?-stroke c? ?-strokeWidth n? ?-rx n? ?-ry n? ?-opacity o? ?-id i?
tusvg::circle   svg cx cy r     ?-fill c? ?-stroke c? ?-strokeWidth n? ?...?
tusvg::ellipse  svg cx cy rx ry ?...?
tusvg::line     svg x1 y1 x2 y2 ?-stroke c? ?-strokeWidth n? ?-strokeLinecap cap? ?...?
tusvg::polyline svg "x,y x,y..." ?...?
tusvg::polygon  svg "x,y x,y..." ?...?
tusvg::path     svg "M.. L.."    ?-fill c? ?-stroke c? ?-strokeLinejoin j? ?...?
tusvg::textElement svg x y "text" ?-fontSize n? ?-fontFamily f? ?-fontWeight w? ?-textAnchor a? ?...?
```

`textElement` (not `text`, which is a Tk command) emits an SVG `<text>` element.

## Gradients and groups

```tcl
set ref [tusvg::linearGradient svg id x1 y1 x2 y2 {{0 "#fff"} {100 "#000"}}]  ;# -> url(#id)
set ref [tusvg::radialGradient svg id cx cy r     {{0 "#fff"} {100 "#000"}}]
set g   [tusvg::group svg ?-transform t? ?-opacity o? ?-id i?]
tusvg::addToGroup g $element
tusvg::addGroup   svg $g
```

## Icon library

```tcl
tusvg::icons                                ;# list of ~110 names
set ic [tusvg::icon name size ?-color c? ?-strokeWidth w?]   ;# an SVG document
tusvg::saveIcon name size file.svg ?-color c?
```

Unknown icon names render a question-mark fallback glyph (no error). Icons are
path/shape only (so they also render under tksvg/svgnano, which has no `<text>`).

## Notes

- No dependencies beyond the Tcl core; works on 8.6 and 9.x.
- Errors carry `{TCLUTILS TUSVG <REASON>}`.

## Demo

```bash
tclsh examples/demo-tusvg.tcl     # writes a scene, an icon sheet and one icon
```
