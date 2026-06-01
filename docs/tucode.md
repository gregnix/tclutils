# tclutils::tucode

Character code tables for bytes 0..255: ASCII, Latin-1/ANSI, and curated
sign groups. Pure Tcl, useful for scripts, docs, and terminal tools.

## Package

```tcl
package require tclutils::tucode 0.1
```

## API

```tcl
::tclutils::tucode::ascii ?options?
::tclutils::tucode::latin1 ?options?
::tclutils::tucode::ansi ?options?          ;# alias for latin1
::tclutils::tucode::table from to ?options?
::tclutils::tucode::render from to ?options?
::tclutils::tucode::signs ?group ...? ?options?
::tclutils::tucode::groups
::tclutils::tucode::lookup code|char|0xNN
```

## Options

```text
-columns N     columns in full tables (default 4)
-showName 0|1   show symbolic name (NUL, nbsp, ssharp, ...)
-compact 1      16-column hex matrix (classic chart layout)
```

## Sign groups

Byte (Latin-1): `controls`, `whitespace`, `quotes`, `dashes`, `german`,
`currency`, `math`, `latin1hi`

Unicode: `arrows`, `boxdraw`, `boxdraw2`

## CLI

```bash
tclsh tucode.tcl ascii
tclsh tucode.tcl latin1
tclsh tucode.tcl ascii -compact 1
tclsh tucode.tcl signs arrows boxdraw
tclsh tucode.tcl groups
tclsh tusign.tcl german quotes
```

## Scope

Byte-oriented tables (0..255), not a full Unicode chart. For Unicode blocks
use dedicated tools; `tucode` focuses on ASCII and Latin-1/ANSI compatibility.
