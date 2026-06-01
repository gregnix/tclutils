# tclutils::tuexpand

`expand`/`unexpand`-like conversion between tabs and spaces in pure Tcl,
with correct tab-stop alignment.

## API
```tcl
::tclutils::tuexpand::expand   text ?-tabs N?
::tclutils::tuexpand::unexpand text ?-tabs N? ?-all 0|1?
::tclutils::tuexpand::file     path ?-mode expand|unexpand? ?-tabs N? ?-all 0|1?
```
`-tabs` sets the tab width (default 8). `unexpand` converts only leading blanks by
default; `-all 1` converts blank runs throughout. Single spaces are never turned
into tabs.

## CLI
```bash
tclsh bin/tuexpand.tcl -tabs 4 file.txt
tclsh bin/tuexpand.tcl unexpand -all 1 file.txt
```
