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

Binary files are always opened in binary mode.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tuzip::createMembers zipfile members args      ;# create a ZIP from in-memory members with per-entry compression and explicit order. `members` is a list of dicts, each with keys: name (archive path, required), content (raw bytes, required), method (stored|deflate, default deflate). The member order is preserved -- e.g. an ODF container can put `mimetype` first as stored and compress the XML parts in a single call. Option -mtime EPOCH sets a fixed timestamp for all entries (default: now)
```
