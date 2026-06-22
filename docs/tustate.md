# tclutils::tustate

Parses a Mermaid `stateDiagram` / `stateDiagram-v2` block into a
`tclutils::tudiagram` model, so a state diagram can render natively (SVG or PNG)
through the pure-Tcl engine — no browser. It is one of the graph-type parsers
the `tclutils::tuflow` facade dispatches to; you normally call `tuflow::toPng` /
`tuflow::toSvg` rather than this module directly.

## Package

```tcl
package require tclutils::tustate 0.1
```

## Commands

```tcl
::tclutils::tustate::parse text      ;# -> tudiagram model dict
```

The result is a `tudiagram` model and is rendered with
`tclutils::tudiagram::toSvg` / `toPng` (or via the `tuflow` facade).

## Supported syntax (Mermaid subset)

```text
states           -> rounded boxes
transitions      -> edges:  A --> B   (optional ": label")
[*]              -> start (__start) / end (__end) marker, by side
"S : text"       -> sets state S's display label
state X <<fork>> -> a labelled box named X (also <<join>>)
direction LR|RL|TB|TD|BT  -> layout direction (RL->LR, BT/TD->TB)
```

## Usage

```tcl
package require tclutils::tustate
package require tclutils::tudiagram

set src {stateDiagram-v2
    [*] --> Idle
    Idle --> Running : start
    Running --> Idle : stop
    Running --> [*]
}
set m [::tclutils::tustate::parse $src]
::tclutils::tudiagram::writePng $m state.png -scale 3
```

## Notes

- v1 limitations (honest): composite states `state X { ... }` are flattened
  (inner transitions kept, the boundary box is not drawn); notes are ignored;
  fork/join render as boxes, not bars; self-loops are not drawn.
- Companion: `tclutils::tudiagram` (renderer), `tclutils::tuflow` (dispatch).

## Error codes

`-errorcode {TCLUTILS TUSTATE <REASON>}` — `EMPTY` (no states/transitions found).
