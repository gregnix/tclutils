# tclutils::turrule

Expand iCalendar `RRULE` recurrence rules into concrete occurrences.

Supported subset of RFC 5545: `FREQ` DAILY/WEEKLY/MONTHLY/YEARLY, `INTERVAL`,
`COUNT`, `UNTIL`, `BYMONTH`, `BYDAY` and `BYMONTHDAY`, `WKST=MO`. Date math is
done in UTC for calendar stability.

| Part | Meaning |
|---|---|
| `BYDAY` | weekday list (`MO,WE`); with MONTHLY/YEARLY also ordinals (`1MO`, `4TH`, `-1FR`) |
| `BYMONTHDAY` | day list, negatives count from the month end; not with WEEKLY |
| `BYMONTH` | month list 1–12; YEARLY expands to these months, other frequencies are limited to them |

YEARLY expands like this: with `BYMONTH` each listed month (a `BYDAY` ordinal
counts within the month: `BYMONTH=11;BYDAY=4TH` is the fourth Thursday of
November); without `BYMONTH` a `BYMONTHDAY` applies to every month, and a
`BYDAY` ordinal counts within the year (`BYDAY=20MO`); without any of them the
DTSTART month and day. When `BYDAY` and `BYMONTHDAY` are both given, only days
matching both remain (`FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13`).

`UNTIL` as a date (`UNTIL=20250120`) includes that whole day; with a time it
is exact.

Any other rule part — `BYSETPOS`, `BYWEEKNO`, `BYYEARDAY`, `BYHOUR`,
`BYMINUTE`, `BYSECOND`, `WKST` other than `MO`, an unknown name — raises
`{TCLUTILS TURRULE UNSUPPORTED}` instead of being ignored.

## API

```tcl
::tclutils::turrule::parse "FREQ=WEEKLY;BYDAY=TU,TH;COUNT=4"   ;# -> dict

::tclutils::turrule::occurrences -dtstart 2025-10-01 \
    -rule "FREQ=WEEKLY;BYDAY=TU,TH;COUNT=4" -from 2025-01-01 -to 2025-12-31
#  -> 2025-10-02 2025-10-07 2025-10-09 2025-10-14
```

Commands:

- `parse rrule` → dict of upper-case parts.
- `occurrences -dtstart ISO -rule RRULE ?-from ISO? ?-to ISO? ?-count N?` →
  occurrence list. `COUNT` is counted from DTSTART; `-from/-to` only window the
  output. The result must be bounded by `-to`, `-count`, `COUNT` or `UNTIL`
  (else `{TCLUTILS TURRULE UNBOUNDED}`). Date-only DTSTART yields dates;
  a datetime DTSTART preserves the time of day.
- `eventsInRange ics fromIso toIso` → list of `{uid summary start}` for every
  VEVENT occurrence in range (uses `tclutils::tuical` to parse). An RRULE with
  an unsupported part raises the error of `occurrences`.

## Errors

`{TCLUTILS TURRULE <REASON>}`:

| Reason | When |
|---|---|
| `FREQ` | no `FREQ`, or an unsupported one |
| `UNBOUNDED` | no `-to`, `-count`, `COUNT` or `UNTIL` |
| `DATE` | a date that cannot be read |
| `UNSUPPORTED` | a rule part outside the subset above |
| `BYDAY` | unknown weekday code, ordinal 0 or above 53, ordinal with DAILY/WEEKLY |
| `VALUE` | `BYMONTH` outside 1–12, `BYMONTHDAY` outside ±1–31 or not an integer |
