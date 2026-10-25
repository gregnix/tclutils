# tclutils::tucode

Character code tables for bytes 0..255: ASCII, Latin-1/ANSI, and curated
sign groups. Pure Tcl, useful for scripts, docs, and terminal tools.

## Package

```tcl
package require tclutils::tucode 0.2
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
::tclutils::tucode::lookup code|char|0xNN|U+NNNN
```

`lookup` accepts a decimal code (`228`), hex with `0x` (`0xE4`), a code
point with `U+` (`U+00E4`, `u+e4`) or a character (`ä`; of several
characters the first one counts). It returns a dict with the keys
`code hex oct glyph name char`.

## Options

```text
-columns N     columns in full tables (default 4)
-showName 0|1   show symbolic name (NUL, nbsp, ssharp, ...)
-compact 1      16-column hex matrix (classic chart layout)
```

`signs` takes the same options; they may stand before or after the group
names (`signs german -showName 0`).

In a full table every name is padded to the longest name of the range,
so the columns line up. In the compact matrix every cell is three
characters wide and the header digits stand over their columns.

## Errors

```text
{TCLUTILS TUCODE RANGE}    code outside 0..255, from > to, not an integer
{TCLUTILS TUCODE LOOKUP}   empty value; character or U+ code point above 255
{TCLUTILS TUCODE GROUP}    unknown sign group
{TCLUTILS COMMON INTEGER -columns}, {TCLUTILS COMMON BOOLEAN -name},
{TCLUTILS COMMON OPTION -name}   bad option value, unknown option, missing value
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
tclsh tucode.tcl signs german quotes -showName 0
tclsh tucode.tcl lookup U+00E4
```

## Scope

Byte-oriented tables (0..255), not a full Unicode chart. For Unicode blocks
use dedicated tools; `tucode` focuses on ASCII and Latin-1/ANSI compatibility.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tucode::lookupChar char                        ;# same as lookup: dict code hex oct glyph name char
```
