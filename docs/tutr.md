# tclutils::tutr

Small `tr`-like text transformation helpers.

## API

```tcl
::tclutils::tutr::translate {abc cab} abc xyz
::tclutils::tutr::delete {a1b2c3} 0-9
::tclutils::tutr::squeeze {aaabccc} ac
```

Commands:

- `translate text set1 set2`
- `delete text set1`
- `squeeze text set1`
- `file path set1 set2 ?-delete bool? ?-squeeze bool?`

Character sets support literal characters and simple ranges like `a-z` or `0-9`.
A `-` at the start or end of a set stands for itself. A descending range such
as `c-a` raises `{TCLUTILS TUTR RANGE}`.

`translate` maps the n-th character of `set1` to the n-th of `set2`; a shorter
`set2` is padded with its last character. A character listed more than once in
`set1` maps to its last partner, as with `tr`. An empty `set2` raises
`{TCLUTILS TUTR SET2}` (unless `set1` is empty as well).

`file` translates `set1` to `set2`, or with `-delete 1` deletes `set1`;
`-squeeze 1` then squeezes the characters of `set2`. With an empty `set2`,
`-squeeze 1` and no `-delete`, `file` only squeezes `set1` (like `tr -s set1`).
An empty `set2` without `-delete` and `-squeeze` raises `{TCLUTILS TUTR SET2}`.

```tcl
::tclutils::tutr::translate abcabc aa xy         ;# -> ybcybc
::tclutils::tutr::file in.txt " " "" -squeeze 1  ;# squeeze blanks only
```

## Errors

| Case | `-errorcode` |
|---|---|
| descending range | `{TCLUTILS TUTR RANGE}` |
| empty `set2` where one is needed | `{TCLUTILS TUTR SET2}` |
| `file`: unknown option | `{TCLUTILS COMMON OPTION -name}` |
| `file`: `-delete`/`-squeeze` not a boolean | `{TCLUTILS COMMON BOOLEAN -name}` |
