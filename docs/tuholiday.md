# tclutils::tuholiday

German public holidays from the Easter computus. Computes Easter Sunday
(Gregorian, Meeus/Jones/Butcher algorithm) and derives the movable feasts, then
returns the **nationwide** German statutory holidays for a year. Pure Tcl on top
of `clock`.

## API

```tcl
::tclutils::tuholiday::easter 2026             ;# -> 2026-04-05
::tclutils::tuholiday::holidays 2026           ;# -> dict {ISO-date -> name}, sorted
::tclutils::tuholiday::isHoliday 2026-01-01    ;# -> "Neujahr"  ("" if none)
```

Commands:

- `easter year` — Easter Sunday of `year` as an ISO date (`YYYY-MM-DD`).
- `holidays year ?-region de?` — the nationwide German holidays as a dict mapping
  ISO date → name, ordered by date (Neujahr, Karfreitag, Oster-/Pfingst-Tage,
  Christi Himmelfahrt, Tag der Arbeit, Tag der Deutschen Einheit, beide
  Weihnachtstage).
- `isHoliday iso ?-region de?` — the holiday name for an ISO date, or `""` if it
  is not a holiday.

Scope: only the nine/eleven days statutory in **all** German states. State-specific
days (Heilige Drei Könige, Fronleichnam, Allerheiligen, Reformationstag, …) are
intentionally not in the base set; `-region` currently accepts only `de`.

Errors: a non-integer year → `{TCLUTILS TUHOLIDAY YEAR}`; an unknown region →
`{TCLUTILS TUHOLIDAY REGION}`.
