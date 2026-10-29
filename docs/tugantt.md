# tclutils::tugantt

Parses a Mermaid `gantt` block and renders it natively (SVG or PNG) through the
pure-Tcl engine. A self-contained 2D renderer in the `tclutils::tuflow` family
(like `tupie` / `tusankey`); normally you call `tuflow::toSvg` / `tuflow::toPng`,
which dispatch here.

## Package

```tcl
package require tclutils::tugantt 0.3
```

## Commands

```tcl
::tclutils::tugantt::parse text                           ;# -> gantt model dict
::tclutils::tugantt::toSvg  model ?-width W? ?-height H? ?-fontfile f? ?-scale n?
::tclutils::tugantt::toPng  model ?...?                   ;# -> PNG bytes
::tclutils::tugantt::writeSvg model file ?...?
::tclutils::tugantt::writePng model file ?...?
```

`writeSvg` and `writePng` write through a temporary file (`common::replaceFile`): a failed write leaves the old file and no open channel (tclutils 0.69.0).

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
  preceding task. The first task needs a start: if it has no date and no
  `after` that names an earlier task, drawing raises `{TCLUTILS TUGANTT DATE}`
  (Mermaid, too, needs a start date; there is no fallback to 1970 or today).
- **Dates** must exist: the parsed date is formatted back with the same format
  and compared with the input (leading zeros do not matter, `2026-3-2` is
  fine). `2026-13-45` or `2026-02-30` raise `DATE` on Tcl 8.6 and 9.0 alike.
- **End**: an explicit date, or a duration `5d` / `2w` / `8h` / `30m` /
  `10s` / `500ms`. Another unit (`5x`) raises `DURATION` (0.3; 0.2 made it
  a task of length 0).
- **Ids** may hold letters of any script (`büro`; 0.2 took such an id for the
  start date and failed on the whole chart).
- `dateFormat` / `axisFormat` accept the usual tokens `YYYY MM DD HH mm ss`
  (mapped to `clock` format); `X` means a Unix timestamp.
- **Axis**: about six ticks, snapped to whole units of the axis format (seconds
  if it shows seconds, minutes if it shows minutes, hours if it shows hours,
  otherwise days); a tick whose label repeats the previous one is dropped, so a
  short span shows each date once.
- Comments start with `%%`.

## v1 scope

Covered: title, dateFormat/axisFormat, sections, tags, ids, explicit dates,
`after` dependencies, durations, and milestones. **Not** in v1: `excludes` /
weekend exclusion, `until`, `vert` markers, compact display mode, and custom
`tickInterval`. Without `-height` the chart grows with the number of tasks
(at least 400 pixels); with `-height` the height is fixed and tasks fill from
the top.

## Options

`-width` (default 800) / `-height` (default 0 = automatic: 400, or more when
the title, the task rows and the axis labels need it -- each task row takes 26
pixels), `-fontfile` (a TTF for real-font labels via `Glyphs`; PNG only --
otherwise the built-in bitmap font), `-scale` (positive integer; on PNG the
canvas grows by the factor; on SVG the canvas keeps its size and text, lines
and spacing grow by the factor).

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
`-scale`), `DATE` (a date that does not match `dateFormat` or does not exist,
or a first task without a start date -- raised when drawing, not by `parse`),
`DURATION` (a duration with an unknown unit, also raised when drawing),
`FONT` (font file not found).
