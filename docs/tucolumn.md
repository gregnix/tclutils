# tclutils::tucolumn

`column`-like columnation in pure Tcl.

## API
```tcl
::tclutils::tucolumn::table text  ?-separator S? ?-output S? ?-right 0|1?
::tclutils::tucolumn::fill  items ?-width N? ?-gap N?
::tclutils::tucolumn::text  text  ?...?           ;# alias for table
::tclutils::tucolumn::file  path  ?-mode table|fill? ?...?
```
Table mode aligns delimited columns (input separator defaults to whitespace runs;
output separator defaults to two spaces). Fill mode arranges items column-major into
columns fitting `-width` (default 80).

## CLI
```bash
tclsh bin/tucolumn.tcl table file.txt
tclsh bin/tucolumn.tcl fill -width 60 words.txt
```
