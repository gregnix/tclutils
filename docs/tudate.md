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
  are tried in this order: ISO date and date-time (also without seconds and
  as `YYYYMMDD`), `d.m.Y` (with optional time), `d/m/Y`, `Y/m/d`, `m/d/Y`,
  `H:M:S`, `H:M`, `d Mon Y`, `Mon d Y`, `Mon d, Y` (English month names).
  `02/03/2026` is 2 March; `m/d/Y` only applies when `d/m/Y` gives no date,
  so `10/29/2026` is 29 October. Then a free-form `clock scan`, but not for
  a string of digits and separators only. Errors `{TCLUTILS TUDATE PARSE}`.
- A day or month that does not exist is an error, with or without
  `-format`, on Tcl 8.6 and 9.0 alike: `2026-02-29`, `31.04.2026`,
  `29/02/2026`, `Feb 30 2026`. Tcl 8.6's `clock scan` alone would roll these
  over (`2026-03-01`, `2026-05-01`, `2028-05-02`); `parse` formats each match
  back and rejects it when the numbers differ (0.3).
- `iso seconds ?-time bool?` — `yyyy-mm-dd` (or `...THH:MM:SS`).
- `add seconds count unit` — calendar add; unit second/minute/hour/day/week/
  month/year (plural or singular). Errors `{TCLUTILS TUDATE UNIT}`.
- `diff a b ?-unit days?` — integer difference (seconds/minutes/hours/days/weeks).
- `relative seconds ?-base secs?` — "today", "yesterday", "in N days", etc.
- `today` — today's ISO date.
- `zones` — sorted time zone names for `clock format -timezone` (e.g.
  `Europe/Berlin`), from Tcl's tzdata, else the system zoneinfo; always
  includes `UTC`. Names from the system directory are checked with `clock`
  first (Tcl 8.6 without own tzdata rejects `Etc/GMT+1` etc.) (0.2).
