# tclutils::tusequence

Parses a Mermaid `sequenceDiagram` block and renders it natively (SVG or PNG)
through the pure-Tcl engine. A self-contained 2D renderer in the
`tclutils::tuflow` family (like `tugantt` / `tusankey`); normally you call
`tuflow::toSvg` / `tuflow::toPng`, which dispatch here.

## Package

```tcl
package require tclutils::tusequence 0.1
```

## Commands

```tcl
::tclutils::tusequence::parse text                      ;# -> sequence model dict
::tclutils::tusequence::toSvg  model ?-width W? ?-height H? ?-fontfile f? ?-scale n?
::tclutils::tusequence::toPng  model ?...?              ;# -> PNG bytes
::tclutils::tusequence::writeSvg model file ?...?
::tclutils::tusequence::writePng model file ?...?
```

`-width` / `-height` default to `0`, meaning the size is computed from the
content. Pass explicit values to override.

## Supported syntax (Mermaid subset)

```text
sequenceDiagram
  participant A            |  participant A as Alias  |  actor A
  autonumber
  A->>B: message
  activate A / deactivate A
  Note left of A: text  |  Note right of A: text  |  Note over A,B: text
  loop / opt / alt(+else) / par(+and) / critical / break / rect
    ...
  end
```

- **Participants** are declared with `participant`/`actor` (optionally
  `... as Alias`) or created implicitly on first use in a message. They render
  in declaration order.
- **Arrows**: `->` `-->` `->>` `-->>` `-x` `--x` `-)` `--)`. One dash = solid,
  two = dotted; `>>` = filled head, `>`/`)` = open head, `x` = cross.
- **Self-messages** (`A->>A: ...`) draw as a loop on the lifeline.
- **Activations**: `activate`/`deactivate`, or the shorthand `+`/`-` on a
  message arrow (`A->>+B` activates B, `B-->>-A` deactivates B).
- **Notes**: `left of` / `right of` / `over` one or two participants.
- **autonumber** prefixes each message with a sequence number.
- **Fragments** `loop` `opt` `alt`(+`else`) `par`(+`and`) `critical` `break`
  `rect` render as labelled, nestable frames; comments start with `%%`.

## v1 scope

`actor` is drawn as a box (no stick figure). Fragment frames span the full
width and are indented per nesting depth, rather than enclosing only the
involved lifelines. Not in v1: create/destroy of participants, `box` grouping,
and actor links/popups.

## Options

`-fontfile` (a TTF for real-font labels via `Glyphs`; PNG only -- otherwise the
built-in bitmap font), `-scale` (positive integer; enlarges the PNG canvas, SVG
ignores it).

## Usage

```tcl
package require tclutils::tusequence
set src {sequenceDiagram
  autonumber
  actor C as Client
  participant S as Server
  participant DB as Database
  C->>+S: Login (user, pass)
  S->>+DB: Select user
  Note over DB: hash not stored raw
  DB-->>-S: Salt & Hash
  alt Hash matches
    S-->>C: 200 OK & JWT
  else Wrong password
    S-->>-C: 401 Unauthorized
  end}
::tclutils::tusequence::writePng [::tclutils::tusequence::parse $src] login.png -scale 2
```

## Notes

- Companion: `tclutils::tusvg` / `tclutils::tupngdraw` (canvas),
  `tclutils::tuflow` (dispatch).
- All shapes use rect / line / polygon primitives, so SVG and PNG output stay
  congruent.

## Error codes

`-errorcode {TCLUTILS TUSEQUENCE <REASON>}` -- `EMPTY` (no participants), `ARG`
(bad `-scale`), `FONT` (font file not found).
