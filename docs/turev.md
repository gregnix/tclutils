# tclutils::turev

`rev`-like reversal of the characters within each line (pure Tcl, Unicode by code point).

## API
```tcl
::tclutils::turev::line str
::tclutils::turev::text text
::tclutils::turev::file path
```
A trailing newline is preserved.

## CLI
```bash
tclsh bin/turev.tcl file.txt
```
