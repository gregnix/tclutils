# tclutils::tunum

Robust parsing and summation of human-formatted numbers in pure Tcl.

`tunum` reads numbers as people write them — with thousands grouping, a comma
or dot as the decimal mark, currency symbols and stray whitespace — and turns
them into plain Tcl doubles. It is GUI-free and library-neutral, usable on its
own or as the numeric backend for table footers (`tkutils::tkutlfooter`).

## Package

```tcl
package require tclutils::tunum 0.1
```

## Commands

```tcl
::tclutils::tunum::parse    s ?-default {}?
::tclutils::tunum::sum      values ?-default 0?
::tclutils::tunum::isNumber s
```

## parse

Parses a single value and returns a Tcl double, or `-default` (empty by
default) when the string is not a recognisable number.

```tcl
::tclutils::tunum::parse "1.234,56"      ;# -> 1234.56   (EU grouping)
::tclutils::tunum::parse "1,234.56"      ;# -> 1234.56   (US grouping)
::tclutils::tunum::parse "1234.56"       ;# -> 1234.56
::tclutils::tunum::parse "12 €"          ;# -> 12.0      (currency stripped)
::tclutils::tunum::parse "-5,5"          ;# -> -5.5
::tclutils::tunum::parse "abc"           ;# -> {}        (unparsable)
::tclutils::tunum::parse "abc" -default 0 ;# -> 0
```

Format detection: a comma followed by digits at the end (`…,56`) is treated as
the decimal mark (EU style) and dots are grouping; otherwise commas are grouping
(US style) and the dot is the decimal mark. Stripped before parsing: the `€`,
`$`, `£`, `¥` symbols and spaces/tabs.

## sum

Sums a list of human-formatted values. Unparsable entries are skipped. Returns
a double, or `-default` (0 by default) when nothing was parsable.

```tcl
::tclutils::tunum::sum {1,50 2,00 4,20}          ;# -> 7.7
::tclutils::tunum::sum {1.000,00 250,50}         ;# -> 1250.5
::tclutils::tunum::sum {10 abc 5}                ;# -> 15.0  (abc skipped)
::tclutils::tunum::sum {} -default {}            ;# -> {}
```

## isNumber

Returns 1 if the value parses as a number, else 0.

```tcl
::tclutils::tunum::isNumber "3,14"   ;# -> 1
::tclutils::tunum::isNumber "x"      ;# -> 0
```

## Error codes

Option errors are raised with `-errorcode {TCLUTILS TUNUM OPTION}`.

## Notes

- Output is always a Tcl double (e.g. `7.7`, not `"7,70"`). Use `format` for
  display formatting, e.g. `format "%.2f" [::tclutils::tunum::sum $vals]`.
- The currency symbol `€` is handled via the `\u20AC` escape, so the module is
  safe to source from a `.tm` regardless of the channel encoding.
- **Relation to `tclutils::tunumfmt`:** the two do *not* overlap. `tunum` parses
  locale-grouped / currency numbers (`1.234,56 €`); `tunumfmt::fromHuman` parses
  SI/IEC unit notation (`1.5K` → 1500, `2Mi` → 2097152). Use `tunum` for
  user-entered amounts, `tunumfmt` for engineering / byte-size notation.
