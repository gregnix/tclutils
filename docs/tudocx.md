# tclutils::tudocx

Minimal Word (`.docx`, Office Open XML) helpers in pure Tcl.

`tudocx` writes simple paragraph documents and reads the text of any Word
document back. It is the counterpart of `tuodf` for Office Open XML and not a
Word toolkit: no styles, tables, images or numbering when writing.

## Package

```tcl
package require tclutils::tudocx 0.1
```

## API

```tcl
::tclutils::tudocx::createText docxFile paragraphs ?-title T? ?-creator C?
::tclutils::tudocx::paragraphs docxFile
::tclutils::tudocx::text docxFile
::tclutils::tudocx::part docxFile name
::tclutils::tudocx::parts docxFile
```

- `createText` writes `[Content_Types].xml`, `_rels/.rels`,
  `word/document.xml` and `docProps/core.xml` / `app.xml`. In a paragraph a
  tab becomes `w:tab`, a newline `w:br`. `-title` and `-creator` go into
  `docProps/core.xml`. Returns the file name.
- `paragraphs` returns the text of every paragraph of the main document part
  (found through `_rels/.rels`, usually `word/document.xml`) in document
  order: headings, list items and table cells included. `w:tab` is `\t`,
  `w:br` is `\n`. Deleted text of tracked changes (`w:delText`) and field
  codes (`w:instrText`) are left out. Headers, footers, footnotes and
  comments are in other parts and are not read.
- `text` joins the paragraphs with `\n`.
- `part` returns one container part as text (UTF-8), `parts` the member
  names.

Errors: `{TCLUTILS TUDOCX PART name}` when there is no main document part;
`{TCLUTILS COMMON OPTION ...}` for bad options. A missing or damaged ZIP is
reported by `tuzip`.

## Example

```tcl
package require tclutils::tudocx

::tclutils::tudocx::createText demo.docx \
    {{First paragraph} {Second with \u00e4\u00f6\u00fc\u00df} {} "a\tb"} \
    -title Demo -creator Tcl
puts [::tclutils::tudocx::text demo.docx]
```

## Notes

Output is deterministic: a fixed timestamp for all entries, no dates in
`docProps/core.xml`. Word, LibreOffice and python-docx open the files.

The reader is a small text extractor with regular expressions, not an XML
parser. Command line: `bin/tudocx.tcl text|parts|create`.
