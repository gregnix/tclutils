# tclutils::tuholiday

Public-holiday dates derived from the Easter computus (Gregorian,
Meeus/Jones/Butcher) plus the fixed dates. Region `de` returns the nine
holidays that are statutory in **all** German states; state-specific days are
intentionally not in the base set.

## API

```tcl
::tclutils::tuholiday::easter 2025                 ;# 2025-04-20
set h [::tclutils::tuholiday::holidays 2025]        ;# dict {ISO -> name}, date-sorted
dict get $h 2025-12-25                              ;# 1. Weihnachtstag
::tclutils::tuholiday::isHoliday 2025-05-01         ;# Tag der Arbeit  ("" if none)
```

Commands: `easter year` ; `holidays year ?-region de?` ; `isHoliday iso ?-region de?`.
Unknown region → `{TCLUTILS TUHOLIDAY REGION}`.
