# tclutils::tuodf

Minimal OpenDocument helpers in pure Tcl: write and read text documents (`.odt`), read slides (`.odp`) and spreadsheets (`.ods`).

`tuodf` creates and reads simple paragraph-based ODF text documents. It is not
a full ODF toolkit; for rich styles, tables, images, spreadsheets, and Draw
content use a dedicated ODF library.

## Package

```tcl
package require tclutils::tuodf 0.2
```

## API

```tcl
::tclutils::tuodf::createText odtFile paragraphs ?-title T? ?-creator C?
::tclutils::tuodf::text odtFile
::tclutils::tuodf::paragraphs odtFile
::tclutils::tuodf::part odtFile name
::tclutils::tuodf::parts odtFile
::tclutils::tuodf::sheets odsFile                 ;# table names, in order
::tclutils::tuodf::rows odsFile ?-sheet NAME|INDEX?  ;# one table as rows
```

`paragraphs` returns the text of every paragraph and heading in document
order (headings since 0.2; up to 0.1 they were left out). It also finds the
paragraphs inside tables and lists, in spreadsheet cells (`.ods`) and on
slides (`.odp`), so `text` works as a plain-text extract for search.

`sheets` and `rows` read a spreadsheet (`.ods`, 0.2). `rows` gives one table
(default the first; `-sheet` takes the name or the index from 1) as a list of
rows, each a list of cell texts: the paragraphs of the cell joined by `\n`,
what the cell shows, not the stored value. A merged-away cell is empty.
Repeated empty cells and rows at the end of a row or table are dropped; a
repeated cell or row with content counts at most 1000 times, so a crafted
file cannot fill the memory. An unknown sheet is `{TCLUTILS TUODF SHEET name}`.

Numeric character references (`&#252;`, `&#x20AC;`) are decoded; up to
2026-10-30 only the five named entities were, and `&#252;` stayed as it was.
A number past Unicode becomes U+FFFD.

## Example

```tcl
package require tclutils::tuodf

::tclutils::tuodf::createText demo.odt \
    {{First paragraph} {Second with äöüß} {} {Fourth}} \
    -title Demo -creator Tcl

puts [::tclutils::tuodf::text demo.odt]
```

## Notes

The generated container keeps `mimetype` as the first entry and stored
(uncompressed). Output uses a fixed valid timestamp for deterministic builds.
All entries are currently stored, not deflated, so generated files are valid but
larger than compressed ODTs.

The reader is a lightweight paragraph extractor, not a complete XML/ODF parser.
