# tclutils::tunumany

A single entry point for "string → number" that **routes** to the right backend
instead of merging them. The two specialised parsers do not overlap:

- locale-grouped / currency amounts (`1.234,56 €`, `1,234.56`) → `tclutils::tunum`
- SI/IEC unit notation (`1.5K`, `2Mi`, `3G`) → `tclutils::tunumfmt`

`tunumany` recognises both notations and dispatches, so callers that may receive
either kind of input have one function to call.

## Package

```tcl
package require tclutils::tunumany 0.1
```

Soft-depends on `tclutils::tunum` and `tclutils::tunumfmt` (each loaded on demand;
a missing backend simply means that notation is not parsed).

## Command

```tcl
::tclutils::tunumany::parse str ?-default VAL? ?-prefer auto|si|locale?
```

Returns the parsed number, or `VAL` (default `""`) when nothing parses.

## Routing

With `-prefer auto` (the default): a plain number followed by an SI/IEC unit
letter (`K M G T P E Z Y`, optional trailing `i`) routes to the SI/IEC backend;
everything else routes to the locale/currency backend. If the chosen route fails
the other is tried as a fallback. Use `-prefer si` or `-prefer locale` to force a
route.

## Examples

```tcl
::tclutils::tunumany::parse "1.234,56"   ;# -> 1234.56   (locale EU)
::tclutils::tunumany::parse "1,234.56"   ;# -> 1234.56   (locale US)
::tclutils::tunumany::parse "12 €"       ;# -> 12.0      (currency)
::tclutils::tunumany::parse "1.5K"       ;# -> 1500      (SI)
::tclutils::tunumany::parse "2Mi"        ;# -> 2097152   (IEC)
::tclutils::tunumany::parse "x" -default 0   ;# -> 0
```

## Notes

- This is the deliberate alternative to merging `tunum` and `tunumfmt`: it keeps
  each parser focused while giving one dispatch point.
- Output is always a Tcl number (or the default); format for display separately.

## Error codes

`-errorcode {TCLUTILS TUNUMANY <REASON>}` (`OPTION`, `PREFER`).
