# tclutils::tuxlsx

Minimal Excel (`.xlsx`, Office Open XML) helpers in pure Tcl.

`tuxlsx` writes one sheet of rows and reads the cell values of any workbook
back. It is not a spreadsheet toolkit: no formats, formulas, column widths or
several sheets when writing; no formatting when reading.

## Package

```tcl
package require tclutils::tuxlsx 0.1
```

## API

```tcl
::tclutils::tuxlsx::writeRows xlsxFile rows ?-sheet NAME? ?-numbers auto|0? ?-title T? ?-creator C?
::tclutils::tuxlsx::sheets xlsxFile
::tclutils::tuxlsx::rows xlsxFile ?-sheet NAME|INDEX?
::tclutils::tuxlsx::text xlsxFile
::tclutils::tuxlsx::part xlsxFile name
::tclutils::tuxlsx::parts xlsxFile
```

- `writeRows` writes ROWS (a list of rows, each a list of cell values) into
  one sheet (`-sheet`, default `Sheet1`). With `-numbers auto` (default) a
  value that looks like a decimal number (`-12`, `3.5`, `1e3`) is stored as a
  number, everything else as text; `-numbers 0` stores every cell as text.
  `007` and `1,5` stay text. Text is written inline, not as shared strings.
  A minimal `styles.xml` is included, so Excel opens the file without a
  repair message. Returns the file name.
- `sheets` returns the sheet names in workbook order.
- `rows` returns the cells of one sheet (`-sheet` by name or 1-based
  number, default the first) as a list of rows. Values as Excel stores them:
  shared and inline strings as text (rich text joined, phonetic runs left
  out), numbers as written in the file (a date is its serial number, a
  percentage its fraction), booleans `1`/`0`, formulas their last computed
  value, errors as text (`#DIV/0!`). Gaps are filled with `""`; a row is as
  long as its last cell, a missing row is an empty list.
- `text` returns all sheets: cells joined by `\t`, rows by `\n`, sheets
  separated by an empty line.
- `part` returns one container part as text, `parts` the member names.

Errors: `{TCLUTILS TUXLSX SHEET name}` unknown sheet;
`{TCLUTILS TUXLSX VALUE}` a sheet name Excel does not accept (empty, more
than 31 characters, one of `[ ] : * ? / \`, starting or ending with `'`);
`{TCLUTILS TUXLSX PART name}` a missing part; `{TCLUTILS COMMON OPTION ...}`
bad options. A missing or damaged ZIP is reported by `tuzip`.

## Example

```tcl
package require tclutils::tuxlsx

::tclutils::tuxlsx::writeRows devices.xlsx {{Item Count} {Printer 3} {Router 1}} -sheet Devices
::tclutils::tuxlsx::sheets devices.xlsx                 ;# -> Devices
::tclutils::tuxlsx::rows devices.xlsx                   ;# -> {Item Count} {Printer 3} {Router 1}
```

## Notes

Output is deterministic (fixed timestamp). Excel, LibreOffice and openpyxl
open the files. The reader is a small scanner, not an XML parser; it reads
what Excel, LibreOffice and openpyxl write. Command line:
`bin/tuxlsx.tcl sheets|rows|text|create`.
