# tclutils::tunum

Robust parsing and summation of human-formatted numbers in pure Tcl.

`tunum` reads numbers as people write them — with thousands grouping, a comma
or dot as the decimal mark, currency symbols and stray whitespace — and turns
them into plain Tcl doubles. It is GUI-free and library-neutral, usable on its
own or as the numeric backend for table footers (`tkutils::tkutlfooter`).

## Package

```tcl
package require tclutils::tunum 0.3
```

Version 0.2 adds the `-locale` option to `parse`; version 0.3 adds `format`.
Both are fully backward compatible: the default `parse` locale `auto` behaves
exactly like 0.1, so existing callers need no change.

## Commands

```tcl
::tclutils::tunum::parse    s ?-default {}? ?-locale auto|de-strict?
::tclutils::tunum::sum      values ?-default 0?
::tclutils::tunum::isNumber s
::tclutils::tunum::format   x ?-locale de? ?-decimals 2?
```

## parse

Parses a single value and returns a Tcl double, or `-default` (empty by
default) when the string is not a recognisable number.

```tcl
::tclutils::tunum::parse "1.234,56"       ;# -> 1234.56   (EU grouping)
::tclutils::tunum::parse "1,234.56"       ;# -> 1234.56   (US grouping)
::tclutils::tunum::parse "1234.56"        ;# -> 1234.56
::tclutils::tunum::parse "12 €"           ;# -> 12.0      (currency stripped)
::tclutils::tunum::parse "-5,5"           ;# -> -5.5
::tclutils::tunum::parse "abc"            ;# -> {}        (unparsable)
::tclutils::tunum::parse "abc" -default 0 ;# -> 0
```

### Locales

`-locale` selects how the decimal mark and grouping are interpreted.

| Locale       | Decimal | Grouping | Currency strip | Use for |
|--------------|---------|----------|----------------|---------|
| `auto` (def) | `,` or `.` (autodetected) | the other | yes (`€ $ £ ¥`, spaces) | user-entered amounts in mixed/unknown notation |
| `de-strict`  | `,` only | `.` **always** | no | strict German input where `.` is unconditionally a thousands separator |

**auto** (default): a comma followed by digits at the end (`…,56`) is treated as
the decimal mark (EU style) and dots are grouping; otherwise commas are grouping
(US style) and the dot is the decimal mark. The `€`, `$`, `£`, `¥` symbols and
spaces/tabs are stripped before parsing.

**de-strict**: the dot is *always* a thousands separator and is removed; the
comma is the decimal mark. No currency stripping is performed. Unparsable input
(including the empty string) returns `-default`. This reproduces the strict
German convention exactly — useful as a drop-in for legacy parsers such as the
Lieferschein `numDe`.

```tcl
set o {-locale de-strict -default 0.0}
::tclutils::tunum::parse "1.234,50" {*}$o   ;# -> 1234.5
::tclutils::tunum::parse "1.000"    {*}$o   ;# -> 1000.0    (dot = thousands)
::tclutils::tunum::parse "956.06"   {*}$o   ;# -> 95606.0   (dot = thousands!)
::tclutils::tunum::parse ".5"       {*}$o   ;# -> 5.0       (dot removed)
::tclutils::tunum::parse "-1.234,50" {*}$o  ;# -> -1234.5
::tclutils::tunum::parse "12,5"     {*}$o   ;# -> 12.5
::tclutils::tunum::parse ""         {*}$o   ;# -> 0.0       (-> -default)
::tclutils::tunum::parse "abc"      {*}$o   ;# -> 0.0       (-> -default)
::tclutils::tunum::parse "5 €"      {*}$o   ;# -> 0.0       (no currency strip)
```

> The `956.06 -> 95606.0` result is intentional: under `de-strict` a dot can
> only be a thousands separator. If your value uses the dot as a decimal mark,
> use `auto` (or normalise to a comma first).

## sum

Sums a list of human-formatted values. Unparsable entries are skipped. Returns
a double, or `-default` (0 by default) when nothing was parsable. `sum` always
parses with the `auto` locale.

```tcl
::tclutils::tunum::sum {1,50 2,00 4,20}          ;# -> 7.7
::tclutils::tunum::sum {1.000,00 250,50}         ;# -> 1250.5
::tclutils::tunum::sum {10 abc 5}                ;# -> 15.0  (abc skipped)
::tclutils::tunum::sum {} -default {}            ;# -> {}
```

## isNumber

Returns 1 if the value parses as a number (auto locale), else 0.

```tcl
::tclutils::tunum::isNumber "3,14"   ;# -> 1
::tclutils::tunum::isNumber "x"      ;# -> 0
```

## format

Formats a number as a grouped, locale-specific string — the rough inverse of
`parse -locale de-strict`. Locale `de` (the only locale, and the default): dot
as thousands separator, comma as decimal mark, `-decimals` fractional digits
(default 2, rounded via Tcl's `format`).

```tcl
::tclutils::tunum::format 1234.5              ;# -> 1.234,50
::tclutils::tunum::format -1234.5             ;# -> -1.234,50
::tclutils::tunum::format 1000000             ;# -> 1.000.000,00
::tclutils::tunum::format 1234.5 -decimals 0  ;# -> 1.234
::tclutils::tunum::format 1234.5 -decimals 3  ;# -> 1.234,500
```

For a currency string, append your own symbol/code:
`"[::tclutils::tunum::format $n] EUR"` -> `1.234,50 EUR`.

> `format` defines a command named `format` inside the `::tclutils::tunum`
> namespace; it calls the Tcl builtin as `::format` internally. Callers always
> use the fully-qualified `::tclutils::tunum::format`, so there is no clash.

## Error codes

| errorcode | raised when |
|-----------|-------------|
| `{TCLUTILS TUNUM OPTION}` | unknown option passed to `parse`/`sum` |
| `{TCLUTILS TUNUM LOCALE}` | `parse -locale` not `auto`/`de-strict`, or `format -locale` not `de` |
| `{TCLUTILS TUNUM DECIMALS}` | `format -decimals` is not a non-negative integer |

## Notes

- Output is always a Tcl double (e.g. `7.7`, not `"7,70"`). Use `format` for
  display formatting, e.g. `format "%.2f" [::tclutils::tunum::sum $vals]`.
- The currency symbol `€` is handled via the `\u20AC` escape, so the module is
  safe to source from a `.tm` regardless of the channel encoding.
- **`auto` vs `de-strict`:** `auto` is forgiving and guesses the notation; pick
  it for free-form user input. `de-strict` is deterministic and never treats a
  dot as a decimal mark; pick it when the input contract is strictly German.
- **Relation to `tclutils::tunumfmt`:** the two do *not* overlap. `tunum` parses
  locale-grouped / currency numbers (`1.234,56 €`); `tunumfmt::fromHuman` parses
  SI/IEC unit notation (`1.5K` → 1500, `2Mi` → 2097152). Use `tunum` for
  user-entered amounts, `tunumfmt` for engineering / byte-size notation.
