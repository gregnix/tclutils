# tclutils::turequirement

Parses a Mermaid `requirementDiagram` block into a `tclutils::tudiagram` model so
it renders natively (SVG or PNG) through the pure-Tcl engine. One of the
graph-type parsers the `tclutils::tuflow` facade dispatches to; normally call
`tuflow::toPng` / `tuflow::toSvg`.

## Package

```tcl
package require tclutils::turequirement 0.1
```

## Commands

```tcl
::tclutils::turequirement::parse text      ;# -> tudiagram model dict
```

## Supported syntax (Mermaid subset)

```text
requirement <name> { id: .. text: .. risk: .. verifymethod: .. }  -> box
element <name> { type: .. docref: .. }                            -> box
<src> - <relation> -> <dst>    (satisfies/derives/traces/...)     -> edge
<dst> <- <relation> - <src>                                       -> edge
```

A requirement / element box carries a `<<type>>` stereotype line, the name and
the collected fields (ASCII only — the bitmap font has no guillemets).

## Usage

```tcl
package require tclutils::turequirement
package require tclutils::tudiagram

set src {requirementDiagram
    requirement test_req {
        id: 1
        text: the system shall boot
        risk: high
        verifymethod: test
    }
    element test_entity {
        type: simulation
    }
    test_entity - satisfies -> test_req
}
::tclutils::tudiagram::writeSvg [::tclutils::turequirement::parse $src] req.svg
```

## Notes

- v1 limitations (honest): long field values (e.g. `text:`) make wide boxes
  (no wrapping); requirement sub-types all render as plain boxes.
- Companion: `tclutils::tudiagram` (renderer), `tclutils::tuflow` (dispatch).

## Error codes

`-errorcode {TCLUTILS TUREQUIREMENT <REASON>}` — `EMPTY` (no requirements/elements found).
