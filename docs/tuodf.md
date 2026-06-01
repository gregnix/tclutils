# tclutils::tuodf

Minimal OpenDocument Text (`.odt`) helpers in pure Tcl.

`tuodf` creates and reads simple paragraph-based ODF text documents. It is not
a full ODF toolkit; for rich styles, tables, images, spreadsheets, and Draw
content use a dedicated ODF library.

## Package

```tcl
package require tclutils::tuodf 0.1
```

## API

```tcl
::tclutils::tuodf::createText odtFile paragraphs ?-title T? ?-creator C?
::tclutils::tuodf::text odtFile
::tclutils::tuodf::paragraphs odtFile
::tclutils::tuodf::part odtFile name
::tclutils::tuodf::parts odtFile
```

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
