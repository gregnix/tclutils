# tclutils::tuzip

Small ZIP helper written in pure Tcl.

## Package

```tcl
package require tclutils::tuzip
```

## Commands

```tcl
::tclutils::tuzip::entries archive.zip
::tclutils::tuzip::names archive.zip
::tclutils::tuzip::readMember archive.zip member/name.txt
::tclutils::tuzip::extract archive.zip member/name.txt out.txt
::tclutils::tuzip::create archive.zip $files -base $directory -compress 1
```

## Notes

`tuzip` currently supports stored entries and deflated entries. This is enough
for common ZIP files and for inspecting ODF files such as `.odt`, `.ods`, `.odg`
and `.odp`, because those files are ZIP containers.

Binary files are always opened in binary mode. `create`, `createMembers` and
`extract` write through a temporary file in the target folder and rename it:
an error while writing leaves the old file (up to 2026-10-30 the target was
opened first and stayed empty). `tudocx`, `tuxlsx` and `tuodf` write through
`createMembers` and get the same.

Member names (0.2): written as UTF-8. A name with non-ASCII characters gets the
UTF-8 flag (general purpose bit 11), and the central directory says "made on
Unix", so Info-ZIP `unzip`, Python and Windows read `Jörg.txt` as `Jörg.txt`.
Up to 0.1 names were written as Latin-1 without the flag (other programs saw
`J÷rg.txt`, a `€` became `?`).

`entries`, `names`, `readMember` and `extract` take `-encoding`:

| value | names without the UTF-8 flag |
|---|---|
| `auto` (default) | UTF-8 when the bytes are valid UTF-8, else CP437 (the ZIP default) |
| any Tcl encoding | that encoding, e.g. `iso8859-1` for archives written by tuzip 0.1 |

Names with the flag are always UTF-8. An unknown encoding is an error
`{TCLUTILS TUZIP ENCODING}`.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tuzip::createMembers zipfile members args      ;# create a ZIP from in-memory members with per-entry compression and explicit order. `members` is a list of dicts, each with keys: name (archive path, required), content (raw bytes, required), method (stored|deflate, default deflate). The member order is preserved -- e.g. an ODF container can put `mimetype` first as stored and compress the XML parts in a single call. Option -mtime EPOCH sets a fixed timestamp for all entries (default: now)
```
