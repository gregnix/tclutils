# tclutils::tukanban

Parses a Mermaid `kanban` block and renders it natively (SVG or PNG) through the
pure-Tcl engine. A self-contained 2D renderer in the `tclutils::tuflow` family
(like `tupie` / `tusankey` / `tupacket`); normally you call `tuflow::toSvg` /
`tuflow::toPng`, which dispatch here. A kanban board is a column layout, not a
node-edge graph, so it does **not** go through `tudiagram`.

## Package

```tcl
package require tclutils::tukanban 0.1
```

## Commands

```tcl
::tclutils::tukanban::parse text                          ;# -> kanban model dict
::tclutils::tukanban::toSvg  model ?-width W? ?-height H? ?-fontfile f? ?-scale n?
::tclutils::tukanban::toPng  model ?...?                  ;# -> PNG bytes
::tclutils::tukanban::writeSvg model file ?...?
::tclutils::tukanban::writePng model file ?...?
```

## Supported syntax (Mermaid subset)

```text
kanban
  <Column Title>                 -> least-indented content line
    <Card text>                  -> a more-indented line
    <Card text>@{ key: val, ... } -> optional metadata
```

- The header line is `kanban`; columns and cards follow.
- **Indentation decides the role.** The first content line after the header
  sets the column indent; lines at that indent are column titles, deeper lines
  are cards of the current column.
- Card metadata after `@{ ... }`: a `priority` value is pulled out and shown as
  a colour badge in the card's top-right (High = red, Medium = orange, Low =
  green, Critical/Blocked = dark red, anything else = grey). The remaining
  `key: value` pairs are shown as a small grey sub-line. The Mermaid keys
  `ticket`, `assigned`, `priority` are typical but not required.
- Blank lines and `%%` comments are ignored.

## Layout (v1)

Columns are laid out left-to-right and fill the canvas evenly. Each column has a
coloured header band (from a fixed qualitative palette), a light lane
background, and its cards stacked top-to-bottom as rounded white boxes. A card
with metadata is drawn taller to fit its sub-line. The canvas size grows
automatically with the column count and the tallest card stack when `-width` /
`-height` are left at their default (`0` = auto).

## v1 limitations (honest)

- `priority` is styled as a badge; other metadata is one joined grey line.
- No card background colours or assignee avatars; long text is clipped.
- Long card text is clipped to the column width, not wrapped or shrunk.
- Cards exceeding the lane height are dropped (the lane does not scroll).

## Options

`-width` (default `0` = auto from column count), `-height` (default `0` = auto
from the tallest stack), `-fontfile` (a TTF for real-font labels via `Glyphs`;
PNG only -- otherwise the built-in 6x8 bitmap font with German umlauts via real
codepoints), `-scale` (positive integer; enlarges the PNG canvas, SVG ignores
it).

## Usage

```tcl
package require tclutils::tukanban
set src {kanban
    Backlog
        Write the spec
        Design the API@{ ticket: DOC-1, priority: High }
    In Progress
        Implement parser@{ assigned: Dev }
    Done
        Review complete@{ ticket: DOC-99 }}
::tclutils::tukanban::writePng [::tclutils::tukanban::parse $src] board.png -scale 3
```

In Markdown, `kanban` rides on the ```` ```mermaid ```` fence, so docir's raster
sinks (pdf / odt / rendererTk) render it through `tuflow::toPng`; no docir
change is needed.

## Notes

- Companion: `tclutils::tusvg` / `tclutils::tupngdraw` (canvas),
  `tclutils::tuflow` (dispatch).
- Headers, lanes, cards and text use only rect/text primitives, so SVG and PNG
  stay congruent.
- `tuflow::parse` rejects `kanban` with `{TCLUTILS TUFLOW UNSUPPORTED}` (it is
  not a node-edge graph); the facade `toSvg`/`toPng` is the render path, exactly
  as for `pie` / `sankey-beta` / `packet-beta`.

## Error codes

`-errorcode {TCLUTILS TUKANBAN <REASON>}` -- `EMPTY` (no header / no columns),
`ARG` (bad `-scale`), `FONT` (font file not found).
