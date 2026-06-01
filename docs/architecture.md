# tclutils architecture

`tclutils` is a Tcllib-style collection of portable utilities written in pure
Tcl. It is intentionally not a full clone of GNU coreutils. The modules are
small library packages with tests, examples, and documentation.

## Layer overview

```text
common
|
|-- text
|   |-- tufind
|   |-- tugrep
|   |-- tuagrep
|   |-- tused
|   |-- tuwc
|   |-- tucat
|   |-- tuhead
|   |-- tutail
|   |-- tusort
|   |-- tuuniq
|   |-- tucut
|   |-- tupaste
|   |-- tujoin
|   |-- tusplit
|   |-- tucsplit
|   |-- tucomm
|   |-- tufold
|   `-- tutr
|
|-- compare
|   |-- tucmp
|   |-- tudiff
|   `-- tupatch
|
|-- archive
|   |-- tuzip
|   `-- tuzipfs
|
|-- data
|   |-- tucsv
|   |-- tujson
|   `-- tuxml
|
|-- binary
|   |-- tubin
|   |-- tuhexdump
|   |-- tuhexedit
|   |-- tuod
|   |-- tuiconv
|   |-- tubase64
|   |-- tucrc
|   `-- tustrings
|
|-- stream-fs
|   |-- tutee
|   |-- tuxargs
|   `-- tustat
|
|-- fuzzy
|   |-- tufuzzy
|   `-- tuagrep
|
`-- document
    |-- tuodf
    |-- tupdf
    `-- tumd
```

## Shared layer

`common` contains reusable helpers for file I/O, binary I/O, line splitting,
delimited splitting, and option parsing. It is not a user-facing Unix-style
command.

## Binary layer

`tubin` is the reusable binary primitive layer. It provides unsigned integer
readers, packers, hex conversion, ASCII-safe rendering, and byte-list helpers.
`tuhexdump`, `tuod`, `tuhexedit`, and `tuzip` use this shared layer where it is
useful.

## Archive layer

`tuzip` handles byte-controlled ZIP creation and reading. This is especially
important for ODF/OOXML-like containers where entry order and stored/deflated
mode can matter. `tuzipfs` is a Tcl 9 ZipFS convenience wrapper and reports a
clear unavailable error on Tcl 8.6.

## Fuzzy layer

`tufuzzy` provides edit-distance, approximate substring distance, similarity,
subsequence, and best-match primitives. `tuagrep` builds approximate grep on top
of those primitives while following the shape of `tugrep`.

## Document helpers

`tuodf`, `tupdf`, and `tumd` are intentionally small inspection/helper modules:

- `tuodf`: create/read simple ODT text documents on top of `tuzip`.
- `tupdf`: read-only PDF structure inspector, not a full PDF parser.
- `tumd`: dependency-free Markdown helper, not a complete Markdown engine.

For full ODF, Markdown, or PDF workflows, these modules are intended as small
scriptable utilities rather than replacements for specialized projects.
