# tclutils::tumindmap

Parses a Mermaid `mindmap` block into a `tclutils::tudiagram` model, so a
mindmap can render natively (SVG or PNG) through the pure-Tcl engine — no
browser. It is one of the graph-type parsers the `tclutils::tuflow` facade
dispatches to; you normally call `tuflow::toPng` / `tuflow::toSvg` rather than
this module directly.

## Package

```tcl
package require tclutils::tumindmap 0.1
```

## Commands

```tcl
::tclutils::tumindmap::parse text      ;# -> tudiagram model dict
```

The result is a `tudiagram` model and is rendered with
`tclutils::tudiagram::toSvg` / `toPng` (or via the `tuflow` facade).

## Supported syntax (Mermaid subset)

```text
indentation      -> hierarchy (relative: a deeper line is a child of the
                    nearest line with smaller indent; tabs count as 4 spaces)
parent -> child  -> edges, drawn without an arrowhead (mindmap connectors)
node shapes:
    ((text))                      -> circle
    {{text}}                      -> hexagon
    [text] (square)               -> box
    (text) / plain text           -> rounded
    )text(    ))text((            -> rounded (cloud/bang, no native shape)
id[text] etc.    -> a leading id token is dropped; the bracket text is the label
```

## Usage

```tcl
package require tclutils::tumindmap
package require tclutils::tudiagram

set src {mindmap
  root((Project))
    Planning
      Scope
      Budget
    Build
      Backend
      Frontend
}
set m [::tclutils::tumindmap::parse $src]
::tclutils::tudiagram::writePng $m mindmap.png -scale 3
```

## Notes

- v1 limitations (honest): the result is laid out as a top-down layered tree
  (`tudiagram`), not the radial Mermaid layout; node ids are generated, so an
  explicit mindmap id is used only as a label source and never as the id;
  `::icon(...)` and `class` decorator lines are ignored; markdown inside a
  label is kept verbatim.
- Companion: `tclutils::tudiagram` (renderer), `tclutils::tuflow` (dispatch).

## Error codes

`-errorcode {TCLUTILS TUMINDMAP <REASON>}` — `EMPTY` (no nodes found).
