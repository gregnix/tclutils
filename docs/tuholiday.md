# tclutils::tuholiday

German public holidays from the Easter computus. Computes Easter Sunday
(Gregorian, Meeus/Jones/Butcher algorithm) and derives the movable feasts, then
returns the German holidays of a year: the nine statutory in all states, by
default with Easter Sunday and Whit Sunday (`-sundays 1`). Pure Tcl on top of
`clock`.

## API

```tcl
::tclutils::tuholiday::easter 2026             ;# -> 2026-04-05
::tclutils::tuholiday::holidays 2026           ;# -> dict {ISO-date -> name}, sorted, 11 days
::tclutils::tuholiday::holidays 2026 -sundays 0 ;# -> the 9 days statutory in all states
::tclutils::tuholiday::isHoliday 2026-01-01    ;# -> "Neujahr"  ("" if none)
```

Commands:

- `easter year` — Easter Sunday of `year` as an ISO date (`YYYY-MM-DD`).
- `holidays year ?-region de? ?-sundays 0|1?` — the German holidays as a dict
  mapping ISO date → name, ordered by date (Neujahr, Karfreitag, Oster-/Pfingst-Tage,
  Christi Himmelfahrt, Tag der Arbeit, Tag der Deutschen Einheit, beide
  Weihnachtstage).
- `isHoliday iso ?-region de? ?-sundays 0|1?` — the holiday name for an ISO date,
  or `""` if it is not a holiday.

Scope: eleven days by default: the nine statutory in **all** German states plus
Easter Sunday and Whit Sunday (Sundays anyway; statutory in a few states only).
`-sundays 0` (since 0.2) leaves the two Sundays out; that is the list of
`tical::holidays::de` without options. State-specific
days (Heilige Drei Könige, Fronleichnam, Allerheiligen, Reformationstag, …) are
intentionally not in the base set; `-region` currently accepts only `de`.

Errors: a non-integer year → `{TCLUTILS TUHOLIDAY YEAR}`; an unknown region →
`{TCLUTILS TUHOLIDAY REGION}`; `-sundays` not 0 or 1 →
`{TCLUTILS TUHOLIDAY SUNDAYS}`.
