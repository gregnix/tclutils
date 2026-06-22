# tclutils::tugantt

Parses a Mermaid `gantt` block and renders it natively (SVG or PNG) through the
pure-Tcl engine. A self-contained 2D renderer in the `tclutils::tuflow` family
(like `tupie` / `tusankey`); normally you call `tuflow::toSvg` / `tuflow::toPng`,
which dispatch here.

## Package

```tcl
package require tclutils::tugantt 0.1
```

## Commands

```tcl
::tclutils::tugantt::parse text                           ;# -> gantt model dict
::tclutils::tugantt::toSvg  model ?-width W? ?-height H? ?-fontfile f? ?-scale n?
::tclutils::tugantt::toPng  model ?...?                   ;# -> PNG bytes
::tclutils::tugantt::writeSvg model file ?...?
::tclutils::tugantt::writePng model file ?...?
```

## Supported syntax (Mermaid subset)

```text
gantt
  title <text>                 optional chart title
  dateFormat <fmt>             input date format (default YYYY-MM-DD)
  axisFormat <fmt>             optional axis label format
  section <name>               start a labelled group of tasks
  <title> : [tags,] [id,] <start>, <end-or-duration>
```

- **Tags** (optional, must come first): `active`, `done`, `crit`, `milestone`.
  They set the bar colour; a `milestone` is drawn as a diamond.
- **Start**: an explicit date, `after <id> [<id> ...]` (the latest end of the
  referenced tasks), or omitted — the task then starts at the end of the
  preceding task.
- **End**: an explicit date, or a duration `5d` / `2w` / `8h` / `30m`.
- `dateFormat` / `axisFormat` accept the usual tokens `YYYY MM DD HH mm ss`
  (mapped to `clock` format); `X` means a Unix timestamp.
- Comments start with `%%`.

## v1 scope

Covered: title, dateFormat/axisFormat, sections, tags, ids, explicit dates,
`after` dependencies, durations, and milestones. **Not** in v1: `excludes` /
weekend exclusion, `until`, `vert` markers, compact display mode, and custom
`tickInterval`. The chart height is fixed (`-height`); tasks fill from the top.

## Options

`-width` / `-height` (default 800 x 400), `-fontfile` (a TTF for real-font
labels via `Glyphs`; PNG only -- otherwise the built-in bitmap font), `-scale`
(positive integer; enlarges the PNG canvas, SVG ignores it).

## Usage

```tcl
package require tclutils::tugantt
set src {gantt
  title Project Plan
  dateFormat YYYY-MM-DD
  section Planning
  Requirements :done, req, 2014-01-01, 4d
  Design       :done, des, after req, 5d
  section Development
  Frontend     :active, fe, after des, 8d
  Backend      :crit, be, after des, 10d
  section Release
  Testing      :test, after be, 4d
  Launch       :milestone, m1, after test, 0d}
::tclutils::tugantt::writePng [::tclutils::tugantt::parse $src] plan.png -scale 2
```

## Notes

- Companion: `tclutils::tusvg` / `tclutils::tupngdraw` (canvas),
  `tclutils::tuflow` (dispatch).
- Bars use rect primitives and milestones a polygon, so SVG and PNG stay
  congruent. Bar colours: normal blue, `active` light blue, `done` grey,
  `crit` red, `milestone` amber.

## Error codes

`-errorcode {TCLUTILS TUGANTT <REASON>}` -- `EMPTY` (no tasks), `ARG` (bad
`-scale`), `DATE` (a date that does not match `dateFormat`), `FONT` (font file
not found).
