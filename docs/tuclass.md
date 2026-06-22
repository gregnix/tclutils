# tclutils::tuclass

Parses a Mermaid `classDiagram` block into a `tclutils::tudiagram` model so it
renders natively (SVG or PNG) through the pure-Tcl engine. One of the graph-type
parsers the `tclutils::tuflow` facade dispatches to; normally call
`tuflow::toPng` / `tuflow::toSvg`.

## Package

```tcl
package require tclutils::tuclass 0.1
```

## Commands

```tcl
::tclutils::tuclass::parse text      ;# -> tudiagram model dict
```

## Supported syntax (Mermaid subset)

```text
class X { +int a; +m() }    -> box with three compartments
X : +int a                     (name / attributes / methods, separated by a
X : +m()                       dashed line; members with "()" are methods)
A <|-- B                    -> edge B->A labelled "extends" (B inherits A)
A *-- B / A o-- B / A ..> B -> labelled edge (composition / aggregation / dependency)
A <|-- B : label            -> an explicit label wins
```

## Usage

```tcl
package require tclutils::tuclass
package require tclutils::tudiagram

set src {classDiagram
    Animal <|-- Dog
    class Animal {
        +String name
        +makeSound()
    }
    class Dog {
        +fetch()
    }
}
::tclutils::tudiagram::writePng [::tclutils::tuclass::parse $src] class.png -scale 3
```

## Notes

- v1 limitations (honest): compartments use a dashed separator line, not drawn
  box dividers; UML arrowheads (hollow triangle, diamond) are not drawn — the
  relationship kind is shown as an edge label instead; cardinality strings
  (`1`, `*`) are ignored.
- Companion: `tclutils::tudiagram` (renderer), `tclutils::tuflow` (dispatch).

## Error codes

`-errorcode {TCLUTILS TUCLASS <REASON>}` — `EMPTY` (no classes found).
