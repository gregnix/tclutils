# tclutils::tuhexedit

Small binary read/write/search/patch helpers in pure Tcl.

`tuhexedit` is a library module, not a GUI editor. It builds on
`tclutils::tubin` and reuses `tclutils::tuhexdump` for dump output.

## Package

```tcl
package require tclutils::tuhexedit 0.2
```

## Read bytes

```tcl
set bytes [::tclutils::tuhexedit::readBytes file.bin 0x100 32]
```

## Write bytes

```tcl
::tclutils::tuhexedit::writeBytes file.bin 0x100 $bytes
```

By default this creates `file.bin.bak`. Pass `0` as fourth argument to disable
backup creation:

```tcl
::tclutils::tuhexedit::writeBytes file.bin 0x100 $bytes 0
```

## Search

```tcl
::tclutils::tuhexedit::findHex file.bin {50 4B 03 04}
::tclutils::tuhexedit::findString file.bin content.xml
```

Both commands return a list of byte offsets.

## Patch

```tcl
::tclutils::tuhexedit::patch file.bin 0x100 {50 4B 03 04}
::tclutils::tuhexedit::patch file.bin 0x100 {50 4B} -backup 0
```

## Dump

```tcl
puts [::tclutils::tuhexedit::dump file.bin -offset 0 -length 128]
```

The dump command delegates to `tclutils::tuhexdump`.

## Limits

`patch` and `writeBytes` are in-place, length-preserving operations. They do
not insert or delete bytes and therefore do not shift the remaining file
content. A write that would pass the end of the file is rejected with
`{TCLUTILS TUHEXEDIT RANGE}`; the file and its backup stay untouched.

`findHex`, `findString`, and `patch` currently read the complete file into
memory. `readBytes` is the partial-read API for large files.

## Errors

```text
{TCLUTILS TUHEXEDIT OFFSET}    offset negative, not an integer, or 0x without hex digits
{TCLUTILS TUHEXEDIT LENGTH}    length negative or not an integer
{TCLUTILS TUHEXEDIT RANGE}     writeBytes/patch would write past the end of the file
{TCLUTILS TUHEXEDIT BYTES}     writeBytes data with a character above 255
{TCLUTILS TUHEXEDIT ENCODING}  findString text the encoding cannot represent
{TCLUTILS TUHEXEDIT NEEDLE}    empty search pattern
{TCL LOOKUP ENCODING name}     unknown encoding (from Tcl)
```

Offsets are a decimal integer or hex with `0x` (`0x100`).

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tuhexedit::backup filename ?backupName?        ;# write a backup copy of FILENAME (default FILENAME plus .bak) before an in-place edit
```
