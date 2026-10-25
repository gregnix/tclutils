# tclutils::tushuf

`shuf`-like line shuffling in pure Tcl. Uses a small self-contained PRNG so a given
`-seed` yields the same permutation on every platform and Tcl version.

## API
```tcl
::tclutils::tushuf::lines lineList ?-seed N? ?-count N?
::tclutils::tushuf::text  text     ?-seed N? ?-count N?
::tclutils::tushuf::file  path     ?-seed N? ?-count N?
```
`-seed N` makes output reproducible (default: time-based). `-count N` outputs at most
N lines; a negative count means all lines.

The seed is an integer of any size, also beyond 32 bits under Tcl 8.6. The
generator uses its low 31 bits, so the order for a given seed is the same on
Tcl 8.6 and 9.0.

## Errors

| Case | `-errorcode` |
|---|---|
| `-seed` not an integer | `{TCLUTILS TUSHUF SEED}` |
| `-count` not an integer | `{TCLUTILS TUSHUF COUNT}` |
| unknown option | `{TCLUTILS COMMON OPTION -name}` |

## CLI
```bash
tclsh bin/tushuf.tcl -seed 42 file.txt
```
