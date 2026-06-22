# tclutils::tuc4

Parses a Mermaid C4 diagram (`C4Context`, `C4Container`, `C4Component`,
`C4Dynamic`, `C4Deployment`) into a `tclutils::tudiagram` model, so a C4 diagram
can render natively (SVG or PNG) through the pure-Tcl engine — no browser. It is
one of the graph-type parsers the `tclutils::tuflow` facade dispatches to; you
normally call `tuflow::toPng` / `tuflow::toSvg` rather than this module directly.

## Package

```tcl
package require tclutils::tuc4 0.1
```

## Commands

```tcl
::tclutils::tuc4::parse text      ;# -> tudiagram model dict
```

The result is a `tudiagram` model and is rendered with
`tclutils::tudiagram::toSvg` / `toPng` (or via the `tuflow` facade).

## Supported syntax (Mermaid subset)

```text
Person(id,"name",...)  Person_Ext(...)        -> rounded box (actor)
System(...) SystemDb(...) SystemQueue(...)     -> box
Container(...) Component(...) and *Db/*Queue   -> box
*_Ext variants                                 -> box
Rel(from,to,"label",...)                       -> edge from -> to, labelled
BiRel / Rel_U|Rel_D|Rel_L|Rel_R(from,to,"...") -> edge (direction hint ignored)
title <text>                                   -> diagram title
*_Boundary(id,"label") { ... }                 -> flattened (inner kept)
UpdateElementStyle / UpdateRelStyle / Update…  -> ignored
```

An element's display label is its `"name"` (the first quoted argument); the
leading id token becomes the node id.

## Usage

```tcl
package require tclutils::tuc4
package require tclutils::tudiagram

set src {C4Context
    title Internet Banking
    Person(customer, "Customer", "A bank customer")
    System(banking, "Banking System", "Web app")
    System_Ext(email, "E-mail System")
    Rel(customer, banking, "Uses")
    Rel(banking, email, "Sends", "SMTP")
}
set m [::tclutils::tuc4::parse $src]
::tclutils::tudiagram::writePng $m c4.png -scale 3
```

## Notes

- v1 limitations (honest): boundaries (`Enterprise_Boundary`, `System_Boundary`,
  `Container_Boundary`, `Boundary`, `Deployment_Node`, `Node`) are flattened —
  their inner elements are kept, the boundary box itself is not drawn; the
  technology/description arguments are not shown (only the name); `BiRel`
  renders as a single-headed edge; the directional `Rel_U/D/L/R` hints are
  ignored (`tudiagram` lays the graph out top-down).
- Companion: `tclutils::tudiagram` (renderer), `tclutils::tuflow` (dispatch).

## Error codes

`-errorcode {TCLUTILS TUC4 <REASON>}` — `EMPTY` (no elements found).
