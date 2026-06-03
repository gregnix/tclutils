# tclutils::tudate

Flexible date helpers built on the Tcl `clock` command: parse common formats,
render ISO, do calendar arithmetic, day differences and human relative phrases.
Works in local time.

## API

```tcl
set t [::tclutils::tudate::parse "15.03.2024"]    ;# epoch seconds
::tclutils::tudate::iso $t                         ;# 2024-03-15
```

Commands:

- `parse str ?-format fmt?` — epoch seconds. Without `-format`, common formats
  are tried (ISO, ISO date-time, `d.m.Y`, `d/m/Y`, `Y/m/d`) then a free-form
  scan; errors `{TCLUTILS TUDATE PARSE}`.
- `iso seconds ?-time bool?` — `yyyy-mm-dd` (or `...THH:MM:SS`).
- `add seconds count unit` — calendar add; unit second/minute/hour/day/week/
  month/year (plural or singular). Errors `{TCLUTILS TUDATE UNIT}`.
- `diff a b ?-unit days?` — integer difference (seconds/minutes/hours/days/weeks).
- `relative seconds ?-base secs?` — "today", "yesterday", "in N days", etc.
- `today` — today's ISO date.
