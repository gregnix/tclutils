# tclutils::tublock

Parses a Mermaid `block-beta` diagram into a `tclutils::tudiagram` model
(best-effort), so it can render natively (SVG or PNG) through the pure-Tcl
engine — no browser. It is one of the graph-type parsers the `tclutils::tuflow`
facade dispatches to; you normally call `tuflow::toPng` / `tuflow::toSvg` rather
than this module directly.

## Package

```tcl
package require tclutils::tublock 0.1
```

## Commands

```tcl
::tclutils::tublock::parse text      ;# -> tudiagram model dict
```

The result is a `tudiagram` model and is rendered with
`tclutils::tudiagram::toSvg` / `toPng` (or via the `tuflow` facade).

## Supported syntax (Mermaid subset)

```text
a b c            -> three boxes (bare ids on one line)
a["Text"]        -> box
a("Text")        -> rounded
a(("Text"))      -> circle
a{"Text"}        -> diamond
a{{"Text"}}      -> hexagon
a(["Text"])      -> stadium
a[("Text")]      -> cylinder
a --> b          -> edge with arrowhead
a --- b          -> edge without arrowhead
a -->|label| b   -> edge with a label
a -- label --> b -> edge with a label
block:groupId ... end  -> flattened (inner blocks kept, group box not drawn)
columns N        -> ignored (layout hint)
space / space:N  -> ignored (empty grid cell)
style/classDef/class/click -> ignored
```

## Usage

```tcl
package require tclutils::tublock
package require tclutils::tudiagram

set src {block-beta
    columns 3
    a["Frontend"] b["API"] c["DB"]
    a --> b
    b --> c
}
set m [::tclutils::tublock::parse $src]
::tclutils::tudiagram::writePng $m block.png -scale 3
```

## Notes

- v1 limitations (honest): the grid geometry of block-beta (columns, widths,
  `:N` spans, explicit placement) is NOT reproduced — `tudiagram` lays the
  blocks out as a top-down graph. Group boundaries are flattened. Node shapes
  map to `tudiagram` `box`/`rounded`/`circle`/`diamond`/`hexagon`/`stadium`/
  `cylinder` (subroutine `[[..]]` -> `box`). Edge endpoints not declared as blocks are created on first use.
- Companion: `tclutils::tudiagram` (renderer), `tclutils::tuflow` (dispatch).

## Error codes

`-errorcode {TCLUTILS TUBLOCK <REASON>}` — `EMPTY` (no blocks found).
