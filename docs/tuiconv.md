# tclutils::tuiconv

`tuiconv` provides small encoding conversion helpers in pure Tcl.

```tcl
package require tclutils::tuiconv

set text [::tclutils::tuiconv::readFile data-cp1252.txt cp1252]
::tclutils::tuiconv::writeFile data-utf8.txt $text utf-8
```

## Commands

```tcl
::tclutils::tuiconv::encodings
::tclutils::tuiconv::convert data fromEncoding toEncoding ?-replace 0|1?
::tclutils::tuiconv::readFile filename encoding ?-replace 0|1?
::tclutils::tuiconv::writeFile filename text encoding ?-replace 0|1?
::tclutils::tuiconv::convertFile infile outfile fromEncoding toEncoding ?-replace 0|1?
```

All file operations use binary channels internally and perform encoding conversion explicitly.

Conversion is strict, the same under Tcl 8.6 and 9 (0.2):

| Case | Error code |
|---|---|
| a character the target encoding cannot hold (`€` in `iso8859-1`) | `TCLUTILS TUICONV UNMAPPABLE enc` |
| bytes that are not valid in the source encoding | `TCLUTILS TUICONV INVALID enc` |
| unknown encoding | `TCLUTILS TUICONV ENCODING enc` |

`-replace 1` substitutes instead: `?` when writing, a replacement character
when reading. `writeFile` converts before it opens the file, so on an error
the file keeps its content. Up to 0.1 Tcl 8.6 wrote `?` without a word and
Tcl 9.0 raised a plain Tcl error.
