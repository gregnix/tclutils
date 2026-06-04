# tclutils::turrule

Expand iCalendar `RRULE` recurrence rules into concrete occurrences.

Supported subset of RFC 5545: `FREQ` DAILY/WEEKLY/MONTHLY/YEARLY, `INTERVAL`,
`COUNT`, `UNTIL`, `BYDAY` (weekday list for WEEKLY; ordinal forms like `1MO` /
`-1FR` for MONTHLY/YEARLY) and `BYMONTHDAY` (day list, negatives count from the
month end). Not supported: `BYSETPOS`, `BYWEEKNO`, `BYYEARDAY`, `BYMONTH`,
non-default `WKST`. Date math is done in UTC for calendar stability.

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
  VEVENT occurrence in range (uses `tclutils::tuical` to parse).
