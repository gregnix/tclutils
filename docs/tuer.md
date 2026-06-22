# tclutils::tuer

Parses a Mermaid `erDiagram` (entity-relationship) block into a
`tclutils::tudiagram` model so it renders natively (SVG or PNG) through the
pure-Tcl engine. One of the graph-type parsers the `tclutils::tuflow` facade
dispatches to; normally call `tuflow::toPng` / `tuflow::toSvg`.

## Package

```tcl
package require tclutils::tuer 0.2
```

Depends on `tclutils::tudiagram 0.3` (the crow's-foot end-marks).

## Commands

```tcl
::tclutils::tuer::parse text      ;# -> tudiagram model dict
```

## Supported syntax (Mermaid subset)

```text
ENTITY { type name [key] ... }   -> a box: entity name plus attribute lines
A <cardinality> B : label        -> a connector A--B labelled <label>, with
                                    crow's-foot cardinality marks at both ends
```

Keys (PK / FK) are appended in parentheses on the attribute line. A `..`
(non-identifying) relationship is drawn dashed, `--` (identifying) solid.

### Cardinality marks

The cardinality on each side of the connector becomes a `tudiagram` end-mark
(`-startMark` on the `A` end, `-endMark` on the `B` end). The mapping is
side-independent — `{`/`}` mean "many", `o` means "zero (optional)":

| Mermaid (left / right) | meaning      | end-mark      |
|------------------------|--------------|---------------|
| `\|\|` / `\|\|`        | exactly one  | `exactlyOne`  |
| `\|o` / `o\|`          | zero or one  | `zeroOrOne`   |
| `}\|` / `\|{`          | one or many  | `oneOrMany`   |
| `}o` / `o{`            | zero or many | `zeroOrMany`  |

So `CUSTOMER ||--o{ ORDER` draws "exactly one" at the customer end and "zero or
many" at the order end.

## Usage

```tcl
package require tclutils::tuer
package require tclutils::tudiagram

set src {erDiagram
    CUSTOMER {
        int id PK
        string name
    }
    ORDER {
        int id PK
        int customer_id FK
    }
    CUSTOMER ||--o{ ORDER : places
}
::tclutils::tudiagram::writeSvg [::tclutils::tuer::parse $src] er.svg
```

## Notes

- Crow's-foot cardinality is drawn via `tudiagram`'s `-startMark` / `-endMark`.
  v1 limitations (honest): long attribute lists make tall boxes (no scrolling);
  attribute keys are shown in parentheses rather than a separate column.
- Companion: `tclutils::tudiagram` (renderer), `tclutils::tuflow` (dispatch).

## Error codes

`-errorcode {TCLUTILS TUER <REASON>}` — `EMPTY` (no entities found).
