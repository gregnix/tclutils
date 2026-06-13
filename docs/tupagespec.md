# tclutils::tupagespec

Parse and format page-range specifications. Turn a human range string like
`"1-3,5,7-"` into a concrete list of page numbers, and the inverse: compact a
list of numbers back into `"1-3,5,7-9"`. Pure Tcl, no dependencies.

## API

```tcl
::tclutils::tupagespec::parse   spec total ?-base 1?   ;# -> sorted unique page list
::tclutils::tupagespec::count   spec total             ;# -> how many pages selected
::tclutils::tupagespec::compact pages                  ;# -> "1-3,5,7-9"
```

`parse` accepts, comma-separated: a single number `N`, a range `A-B` (`A>B` is
tolerated), an open end `A-` (A..total), an open start `-B` (1..B); the keywords
`end`/`last` stand for `total`; an empty spec or `all`/`*` selects every page.
`-base 1` (default) returns 1-based page numbers, `-base 0` returns 0-based.

```tcl
tupagespec::parse "1-3,5"  10          ;# -> 1 2 3 5
tupagespec::parse "5-"     8           ;# -> 5 6 7 8
tupagespec::parse "-3"     8           ;# -> 1 2 3
tupagespec::parse "4-last" 6           ;# -> 4 5 6
tupagespec::parse "2-4"    10 -base 0  ;# -> 1 2 3
tupagespec::compact {1 2 3 5 7 8}      ;# -> "1-3,5,7-8"
```

`parse` and `compact` round-trip: `compact [parse $spec $total]` re-emits an
equivalent, normalised spec.

## Errors

Carry `{TCLUTILS TUPAGESPEC <REASON>}`: `SYNTAX` (unparseable part), `RANGE`
(page outside `1..total`), `OPTION` (unknown option), `VALUE` (bad `-base` or
`total`).

## Demo

```bash
tclsh examples/demo-tupagespec.tcl
```
