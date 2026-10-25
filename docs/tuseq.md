# tclutils::tuseq

`seq`-like numeric sequence generation in pure Tcl.

## API
```tcl
::tclutils::tuseq::range ?first? ?incr? last ?options?
::tclutils::tuseq::text  ?first? ?incr? last ?options?
```
Positional forms: `last`, `first last`, or `first incr last` (negative steps allowed).
Options: `-separator S` (text only, default newline), `-format F` (printf format),
`-equalwidth 0|1` (pad numbers with leading zeros to equal width).

Options may stand before, between or after the values. An argument that starts
with `-` and is not a number starts an option; negative numbers are values.
`range` rejects `-separator` as an unknown option.

When all three values are integers (of any size, also 64-bit values under
Tcl 8.6), the sequence is computed with integers; otherwise with doubles,
formatted with `%g`.

```tcl
::tclutils::tuseq::text 3 -separator ,          ;# -> 1,2,3
::tclutils::tuseq::range 5000000000 5000000001  ;# -> 5000000000 5000000001
```

## Errors

| Case | `-errorcode` |
|---|---|
| no value or more than three | `{TCLUTILS TUSEQ ARGS}` |
| value is not a number | `{TCLUTILS TUSEQ VALUE}` |
| increment 0 | `{TCLUTILS TUSEQ INCREMENT}` |
| option without value | `{TCLUTILS TUSEQ OPTION}` |
| unknown option (also `-separator` for `range`) | `{TCLUTILS COMMON OPTION -name}` |

## CLI
```bash
tclsh bin/tuseq.tcl 1 2 10
tclsh bin/tuseq.tcl -equalwidth 1 8 11
```
