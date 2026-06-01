# tclutils::tunl

`nl`-like line numbering in pure Tcl.

## API
```tcl
::tclutils::tunl::text text ?options?
::tclutils::tunl::file path ?options?
```
Options: `-style all|nonempty|none` (default `nonempty`), `-start N` (default 1),
`-increment N` (default 1), `-width N` (default 6), `-separator S` (default tab).
A trailing newline is preserved and is not numbered.

## CLI
```bash
tclsh bin/tunl.tcl -width 3 -separator " " file.txt
```
