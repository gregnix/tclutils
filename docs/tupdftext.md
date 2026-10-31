# tclutils::tupdftext

Text of a PDF, page by page, in pure Tcl. Meant for full-text search: words,
spaces and line breaks come out; columns and tables only as far as the order
in the PDF gives them. No poppler, no C extension; the streams are unpacked
with Tcl's built-in `zlib`. A numeric-looking string from the page stays text (0.2).

## Package

```tcl
package require tclutils::tupdftext 0.2
```

## API

```tcl
::tclutils::tupdftext::pages   file ?-notext error|empty?
::tclutils::tupdftext::text    file ?-separator s? ?-notext error|empty?
::tclutils::tupdftext::summary file
```

`pages` returns a list with the text of every page, in page order. Lines are
separated by `\n`, runs of blanks folded, ligatures (`ﬁ`, `ﬂ`, …) written
out, soft hyphens removed.

`text` joins the pages with `-separator` (default form feed `\f`, as
`pdftotext` does).

`summary` returns a dict:

| Key | Meaning |
|-----|---------|
| `pages` | number of pages |
| `encrypted` | 1 if the file has an `/Encrypt` entry |
| `version` | header version, e.g. `1.7` |
| `textPages` | pages with at least one character |
| `unmapped` | glyphs that came out as U+FFFD (two-byte font without `/ToUnicode`) |
| `fonts` | list of dicts `name subtype toUnicode` for the fonts used |

With `-notext empty` a PDF without any text gives empty strings instead of
the error `NOTEXT`.

## Errors

All errors carry `-errorcode {TCLUTILS TUPDFTEXT <kind>}`:

| Kind | When |
|------|------|
| `FILE` | the file cannot be read |
| `FORMAT` | no `%PDF-` header, no objects, or no pages |
| `ENCRYPTED` | the file is encrypted (no decryption) |
| `NOTEXT` | no page has any text: a scan without OCR, or images only |
| `OPTION` | unknown option or missing value |

## What it reads

- **Objects** by scanning for `N G obj` at the start of a line. The
  cross-reference table is not needed; a damaged one does no harm. A later
  definition of the same number wins, as with an incremental update.
  Objects in object streams (`/ObjStm`) fill in the numbers not defined
  directly.
- **Filters** `FlateDecode` (also with PNG predictor), `ASCIIHexDecode`,
  `ASCII85Decode`, `LZWDecode`, and chains of them.
- **Pages** through the page tree from `/Root`, with inherited `/Resources`.
  Without a usable tree: all `/Type /Page` objects in file order.
- **Text operators** `Tj TJ ' "` with `Tf Tc Tw Tz TL Ts Td TD Tm T*` and
  `q Q cm`; Form XObjects (`Do`) with their own resources and matrix, up to
  depth 8, a form that draws itself is drawn once. Inline images are skipped.
- **Fonts** Type0 (two-byte codes, `Identity-H`/`-V` or an embedded CMap),
  Type1, TrueType, Type3. Unicode from `/ToUnicode` (`bfchar`, `bfrange`
  with offset or array), otherwise from `/Encoding`: `WinAnsiEncoding`,
  `MacRomanEncoding`, `StandardEncoding`, `PDFDocEncoding`, and
  `/Differences` with glyph names (WinAnsi names, `uniXXXX`, `uXXXX`,
  ligatures).
- **Spaces and line breaks** from the positions in device space, with the
  glyph widths from `/Widths`, `/W` and `/DW`: a jump down by half a line
  is a new line, a gap of more than 0.15 em on the same line a space.

## What it does not do

- decrypt (`ENCRYPTED`), not even with an empty user password
- read text from images (a scan needs OCR first)
- map a two-byte font without `/ToUnicode` (U+FFFD, counted in `unmapped`)
- keep columns apart: text comes in the order of the content stream
- join words hyphenated at the end of a line (`pdftotext` does)

## Measured

2026-10-21, Tcl 8.6.14 and 9.0.4, Linux. Words (letters and digits, lower
case) compared with `pdftotext` (poppler 24.02): share of the pdftotext words
that `tupdftext` also gives, and the other way round.

| PDF | Producer | Pages | Time 8.6 | pdftotext words found | own words in pdftotext |
|-----|----------|------:|---------:|----------------------:|-----------------------:|
| Tcl/Tk unter Windows | pdf4tcl 0.9.4.72, CID fonts | 86 | 3.1 s | 99.94 % | 99.89 % |
| Tcl/Tk unter macOS | pdf4tcl 0.9.4.72 | 108 | 3.6 s | 99.91 % | 99.82 % |
| Debian unter Linux | pdf4tcl 0.9.4.72 | 32 | 0.9 s | 99.94 % | 99.87 % |
| DocIR handbook | pdf4tcl 0.9.4.72 | 9 | 0.3 s | 100 % | 100 % |
| same, `qpdf --object-streams=generate` | qpdf | 9 | 0.3 s | 100 % | 100 % |
| same, `qpdf --qdf` | qpdf | 9 | 0.3 s | 100 % | 100 % |
| HTML book through LibreOffice | LibreOffice 24.2 | 150 | 3.6 s | 99.79 % | 99.57 % |
| DOCX through LibreOffice | LibreOffice 24.2 | 7 | 0.4 s | 99.95 % | 99.90 % |
| EuroTcl 2025 slides | PowerPoint (Microsoft 365) | 27 | 1.2 s | 100 % | 100 % |
| Latin Modern info | xdvipdfmx, Type1 | 26 | 2.7 s | 98.57 % | 98.80 % |
| TeX Gyre Heros info | mbt PDF assembleur | 33 | 3.6 s | 99.49 % | 99.56 % |
| math test (Word) | Ghostscript 9.02 | 1 | 0.04 s | 91.18 % | 91.18 % |
| math test (LuaLaTeX) | LuaTeX 0.70 | 1 | 0.04 s | 90.62 % | 96.67 % |

The remaining differences: words hyphenated at a line end (pdftotext joins
them), ligatures (written out here, a separate word for pdftotext), and the
two-dimensional layout of formulas. An encrypted file
(`qpdf --encrypt … 256`) gives `ENCRYPTED`. Tcl 9.0.4 gives the same text as
8.6.14; characters outside the BMP come as one character on 9 and as a
surrogate pair on 8.6.

## Command line

```sh
tclsh bin/tupdf.tcl text doc.pdf            # all pages, form feed between
tclsh bin/tupdf.tcl text doc.pdf -page 3
```

## Example

```tcl
package require tclutils::tupdftext

# search a folder of PDFs, report the pages
proc pdfgrep {dir word} {
    foreach f [glob -nocomplain -directory $dir *.pdf] {
        if {[catch {::tclutils::tupdftext::pages $f} pages opts]} {
            puts "$f: [lindex [dict get $opts -errorcode] end]"
            continue
        }
        set n 0
        foreach p $pages {
            incr n
            if {[string match -nocase *$word* $p]} { puts "$f: page $n" }
        }
    }
}
```

## See also

`tclutils::tupdf` inspects the structure (version, objects, trailer,
metadata, ZUGFeRD). `tupdftext` reads the text.
