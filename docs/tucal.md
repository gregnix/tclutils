# tclutils::tucal

`cal`-like calendar output in pure Tcl.

## Package

```tcl
package require tclutils::tucal 0.2
```

## API

```tcl
::tclutils::tucal::month ?month? ?year? ?options?
::tclutils::tucal::now ?options?
::tclutils::tucal::render year month ?options?
::tclutils::tucal::year year ?options?
::tclutils::tucal::three ?month? ?year? ?options?
```

## Options

```text
-mondayfirst 0|1   week starts on Monday (default: Sunday)
-weeknumbers 0|1   show week numbers in the left column
-iso 0|1           ISO week numbers (sets -mondayfirst 1 and -weeknumbers 1)
-locale name       Tcl clock locale, e.g. de_DE, fr_FR (month/day names)
```

With `-locale`, month titles and weekday headers use Tcl's `clock format -locale`.
Default (empty `-locale`) keeps English abbreviations `Mo Tu We …`.

With `-weeknumbers 1` and `-mondayfirst 1`, Tcl's `%V` gives ISO week numbers.
With Sunday-first weeks, `%U` is used instead.

## Layout

A month is a grid of 7 day columns, 3 characters wide in `month`, `render`
and `three` (27 columns), 2 characters wide in `year` (20 columns). Week
numbers add a 4-column prefix (31 or 24 columns). The month title is centred
over the day columns. `three` sets three months side by side, `year` four rows
of three months (January, February, March in the first row, like `cal -y`),
two blanks between the blocks; the year is centred over the full width (64
columns without week numbers). No output line ends in a blank.

```text
         May 2026
 Su  Mo  Tu  We  Th  Fr  Sa
                      1   2
  3   4   5   6   7   8   9
 10  11  12  13  14  15  16
 17  18  19  20  21  22  23
 24  25  26  27  28  29  30
 31
```

## Examples

```tcl
puts [::tclutils::tucal::month 5 2026 -locale de_DE -iso 1]
puts [::tclutils::tucal::month 5 2026 -locale fr_FR]
```

```bash
tclsh tucal.tcl 5 2026 -locale de_DE -w
```

## Scope

This module prints text calendars. It is not a scheduling or iCal library.
Locale support uses Tcl `clock format -locale` and depends on OS locale data.

## More examples

```tcl
puts [::tclutils::tucal::month]
puts [::tclutils::tucal::month 5 2026 -iso 1]
puts [::tclutils::tucal::year 2026 -locale de_DE]
```

```bash
tclsh tucal.tcl -y 2026 -locale de_DE
```
