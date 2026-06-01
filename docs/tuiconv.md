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
::tclutils::tuiconv::convert data fromEncoding toEncoding
::tclutils::tuiconv::readFile filename encoding
::tclutils::tuiconv::writeFile filename text encoding
::tclutils::tuiconv::convertFile infile outfile fromEncoding toEncoding
```

All file operations use binary channels internally and perform encoding conversion explicitly.
