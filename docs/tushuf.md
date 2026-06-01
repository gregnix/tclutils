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
N lines.

## CLI
```bash
tclsh bin/tushuf.tcl -seed 42 file.txt
```
