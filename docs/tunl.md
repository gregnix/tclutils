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

`-start` and `-increment` are integers (negative allowed, any size); `-width`
is an integer of at least 1. The number is right-aligned in `-width` columns.

## Errors

| Case | `-errorcode` |
|---|---|
| `-style` not `all`, `nonempty`, `none` | `{TCLUTILS TUNL STYLE}` |
| `-start` not an integer | `{TCLUTILS TUNL START}` |
| `-increment` not an integer | `{TCLUTILS TUNL INCREMENT}` |
| `-width` not an integer >= 1 | `{TCLUTILS TUNL WIDTH}` |
| unknown option | `{TCLUTILS COMMON OPTION -name}` |

## CLI
```bash
tclsh bin/tunl.tcl -width 3 -separator " " file.txt
```
