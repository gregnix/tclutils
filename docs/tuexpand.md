# tclutils::tuexpand

`expand`/`unexpand`-like conversion between tabs and spaces in pure Tcl,
with correct tab-stop alignment.

## API
```tcl
::tclutils::tuexpand::expand   text ?-tabs N?
::tclutils::tuexpand::unexpand text ?-tabs N? ?-all 0|1?
::tclutils::tuexpand::file     path ?-mode expand|unexpand? ?-tabs N? ?-all 0|1?
```
`-tabs` sets the tab width (default 8). `-all` belongs to `unexpand` only;
`expand` rejects it as an unknown option.

`unexpand` converts only the leading blanks (spaces and tabs) by default and
copies the rest of the line unchanged, so tabs inside the line stay tabs.
`-all 1` converts every run of blanks. Within a run of two or more blanks, or a
run at the start of the line, each tab stop the run reaches becomes a tab; the
spaces left after the last stop stay spaces. A single space inside the line
stays a space, also right before a tab stop. Spaces right before a tab are
absorbed by it. This matches GNU `unexpand` (`-a` for `-all 1`).

```tcl
::tclutils::tuexpand::unexpand "a\tb"                       ;# -> a\tb
::tclutils::tuexpand::unexpand "abcdefg          x" -all 1  ;# -> abcdefg\t\t x
```

## Errors

| Case | `-errorcode` |
|---|---|
| `file`: unknown `-mode` | `{TCLUTILS TUEXPAND MODE}` |
| `file`: `-mode` without value | `{TCLUTILS TUEXPAND OPTION}` |
| unknown option (also `-all` for `expand`) | `{TCLUTILS COMMON OPTION -name}` |
| `-tabs` not a positive integer | `{TCLUTILS COMMON INTEGER -tabs}` |
| `-all` not a boolean | `{TCLUTILS COMMON BOOLEAN -all}` |

## CLI
```bash
tclsh bin/tuexpand.tcl -tabs 4 file.txt
tclsh bin/tuexpand.tcl unexpand -all 1 file.txt
```
