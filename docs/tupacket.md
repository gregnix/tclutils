# tclutils::tupacket

Parses a Mermaid `packet-beta` block and renders it natively (SVG or PNG)
through the pure-Tcl engine. A self-contained 2D renderer in the
`tclutils::tuflow` family (like `tupie` / `tukanban`); normally you call
`tuflow::toSvg` / `tuflow::toPng`, which dispatch here. A packet layout is a
bit-field table, not a node-edge graph, so it does **not** go through
`tudiagram`.

## Package

```tcl
package require tclutils::tupacket 0.1
```

## Commands

```tcl
::tclutils::tupacket::parse text                          ;# -> packet model dict
::tclutils::tupacket::toSvg  model ?-width W? ?-height H? ?-fontfile f? ?-scale n?
::tclutils::tupacket::toPng  model ?...?                  ;# -> PNG bytes
::tclutils::tupacket::writeSvg model file ?...?
::tclutils::tupacket::writePng model file ?...?
```

## Supported syntax (Mermaid subset)

```text
packet-beta
title <text>             -> optional, own line (or "packet-beta title <text>")
<start>-<end>: "Label"   -> a bit range, inclusive
<bit>: "Label"           -> a single bit (start == end)
```

- The header line is `packet-beta` (or bare `packet`); fields follow.
- The label may be quoted (`"..."` / `'...'`) or bare.
- Blank lines and `%%` comments are ignored. Bit indices are integers.
- Fields are sorted by start bit; **overlapping** ranges and an **end before
  start** are parse errors. Bits no field covers (within the used range) are
  drawn as light-grey gap cells.

## Layout (v1)

Bits are laid out **32 per row** (the Mermaid default). Each row draws the
start/end bit index of every field segment along the top and the fields as
filled cells below, coloured from a fixed qualitative palette. A field that
crosses a row boundary is split into per-row segments that share one colour; its
label is drawn once, centred in its widest segment, and clipped (not wrapped) if
longer than the cell. The canvas height grows automatically with the number of
rows when `-height` is left at its default (`0` = auto).

## v1 limitations (honest)

- Bits-per-row is fixed at 32; Mermaid's `packet` config block is not parsed.
- No theming or per-field colour configuration.
- Long labels are clipped to their cell, not wrapped or shrunk.
- A field crossing a row boundary is split visually; the label sits in the
  widest part only.

## Options

`-width` (default 640), `-height` (default `0` = auto from the row count),
`-fontfile` (a TTF for real-font labels via `Glyphs`; PNG only -- otherwise the
built-in 6x8 bitmap font with German umlauts via real codepoints), `-scale`
(positive integer; enlarges the PNG canvas, SVG ignores it).

## Usage

```tcl
package require tclutils::tupacket
set src {packet-beta
    title IPv4 (simplified)
    0-3: "Version"
    4-7: "IHL"
    8-15: "Total Length"
    16-31: "Identification"
    32-63: "Flags + Fragment + TTL + Protocol"}
::tclutils::tupacket::writePng [::tclutils::tupacket::parse $src] ipv4.png -scale 3
```

In Markdown, `packet-beta` rides on the ```` ```mermaid ```` fence, so docir's
raster sinks (pdf / odt / rendererTk) render it through `tuflow::toPng`; no
docir change is needed.

## Notes

- Companion: `tclutils::tusvg` / `tclutils::tupngdraw` (canvas),
  `tclutils::tuflow` (dispatch).
- Cells, gaps and ticks use only rect/text primitives, so SVG and PNG stay
  congruent.
- `tuflow::parse` rejects `packet-beta` with `{TCLUTILS TUFLOW UNSUPPORTED}` (it
  is not a node-edge graph); the facade `toSvg`/`toPng` is the render path,
  exactly as for `pie` / `kanban`.

## Error codes

`-errorcode {TCLUTILS TUPACKET <REASON>}` -- `EMPTY` (no header / no fields),
`RANGE` (overlap or end-before-start), `VALUE` (unparseable field line), `ARG`
(bad `-scale`), `FONT` (font file not found).
