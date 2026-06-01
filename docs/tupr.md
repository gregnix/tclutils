# tclutils::tupr

`pr`-like simple page formatting in pure Tcl.

## API
```tcl
::tclutils::tupr::text text ?options?
::tclutils::tupr::file path ?options?
```
Options: `-length N` (lines per page, default 66; 5-line header + 5-line footer),
`-header S` (title), `-width N` (header layout width, default 72),
`-number 0|1` (number body lines), `-date S` (header date; default current date/time).
`file` uses the file name as the default header.

## CLI
```bash
tclsh bin/tupr.tcl -header "Report" -number 1 file.txt
```
