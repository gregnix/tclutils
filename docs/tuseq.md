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

## CLI
```bash
tclsh bin/tuseq.tcl 1 2 10
tclsh bin/tuseq.tcl -equalwidth 1 8 11
```
