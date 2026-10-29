# tclutils::tuclass

Parses a Mermaid `classDiagram` block into a `tclutils::tudiagram` model so it
renders natively (SVG or PNG) through the pure-Tcl engine. One of the graph-type
parsers the `tclutils::tuflow` facade dispatches to; normally call
`tuflow::toPng` / `tuflow::toSvg`.

## Package

```tcl
package require tclutils::tuclass 0.3
```

## Commands

```tcl
::tclutils::tuclass::parse text      ;# -> tudiagram model dict
```

## Supported syntax (Mermaid subset)

```text
class X {                   -> box with three compartments
    +int a                     (name / attributes / methods, separated by a
    +m()                       dashed line; members with "()" are methods)
}
class X { +int a; +m() }    -> the same block on one line, ";" between members
                               (a ";" inside double quotes stays in the member, 0.3)
class X { }                 -> a class without members (the block is closed)
X : +int a                  -> member added outside a block
X : +m()
A <|-- B                    -> edge B->A labelled "extends" (B inherits A)
A *-- B / A o-- B / A ..> B -> labelled edge (composition / aggregation / dependency)
A <|-- B : label            -> an explicit label wins
A "1" --> "*" B : label     -> cardinality strings are accepted and dropped;
                               the edge A->B stays
```

Members written in front of a closing `}` still count (`+m() }`).

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
  (`1`, `*`) are parsed but not drawn (the model has no field for them).
- Companion: `tclutils::tudiagram` (renderer), `tclutils::tuflow` (dispatch).

## Error codes

`-errorcode {TCLUTILS TUCLASS <REASON>}` — `EMPTY` (no classes found).
