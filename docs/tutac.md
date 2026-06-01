# tclutils::tutac

`tac`-like reversal of line order (pure Tcl).

## API
```tcl
::tclutils::tutac::text text
::tclutils::tutac::file path
::tclutils::tutac::lines lineList
```
A trailing newline is preserved (so `a\nb\n` becomes `b\na\n`).

## CLI
```bash
tclsh bin/tutac.tcl file.txt
```
