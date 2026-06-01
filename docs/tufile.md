# tclutils::tufile

Magic-signature file type detection in pure Tcl, like Unix `file`, with a
user-extensible signature table and extension-mismatch checking. Reads only the
file header.

## Package

```tcl
package require tclutils::tufile 0.1
```

## API

- `tufile::detect path`        -> dict of the most specific match, or empty dict
- `tufile::type path`          -> short name (`png`, `pdf`, `odt`, ...) or `""`
- `tufile::mime path`          -> MIME type or `""`
- `tufile::describe path`      -> human-readable description or `"data"`
- `tufile::checkExtension path`-> dict `{path detected declared expected status}`
  with `status` in `ok | mismatch | noext | unknown | unknownext`
- `tufile::register name -offset N (-hex HEX | -ascii STR) -mime M -ext {e ...} -desc D`
- `tufile::loadFile path`      -> load signatures from a text file (returns count)
- `tufile::forget name` / `tufile::reset`
- `tufile::signatures`         -> list of signature names

Signature file format (one per line, `#` comments, `|`-separated):

```
# name | offset | marker | mime | ext1,ext2 | description
foofmt | 0 | @FOO!   | application/x-foo | foo,fo | Foo format
barfmt | 4 | CAFE    | application/x-bar | bar    | Bar format
```

A leading `@` marks the marker as ASCII text; otherwise it is hex.

## CLI

```bash
tclsh bin/tufile.tcl file                 # describe, like Unix file
tclsh bin/tufile.tcl check *.jpg          # extension vs content
tclsh bin/tufile.tcl -sigs my.txt type x.bin
```

## Scope

Offset + exact byte pattern match model (no masks, ranges, or nested rules like
libmagic). ODT/ODS/ODP are recognized via the offset-30 `mimetype` marker;
DOCX/XLSX/PPTX share only the ZIP magic and are reported as `zip`.
