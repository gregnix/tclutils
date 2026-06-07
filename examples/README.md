# Examples

This folder ships **no PNGs** -- every image is produced by a script, from the
shipped modules only. Run a script to generate its output (written to the
script's directory by default, or to an output dir you pass as the first arg --
that first argument is a directory, not a font; it is created if missing).

## Reproducible (no external dependencies)

    tclsh generate-examples.tcl        ?out-dir?   # tupngdraw + tutablepng
    tclsh generate-month-demos.tcl     ?out-dir?   # tumonthpng calendars
    tclsh generate-codepage-demos.tcl  ?out-dir?   # tucodepng character tables

`generate-examples.tcl` produces:
- `tupngdraw-aafills-joins.png` - AA pie/polygon/ellipse fills, round/bevel/mitre
  joins, and a `fillcontours` star-with-hole (evenodd).
- `tupngdraw-umlauts.png` - the built-in 6x8 font incl. German umlauts/eszett.
- `tutablepng-demo.png` - a styled data table (header, alignment, zebra).

`generate-month-demos.tcl` produces month calendars:
- `month-default.png`, `month-dark.png`, `month-light.png` - the three themes
  for June 2026 with today, a holiday and notes marked.
- `month-noweeks.png` - default theme without the ISO week-number column.
- `month-2026-01.png`, `month-2026-02.png`, `month-2026-12.png` - layout
  variation across months.
- `quarter-2026-Q1.png` - three months side by side (renderQuarter).
- `year-2026.png` - a full-year poster, 3 columns (renderYear).

All output is byte-identical on Tcl 8.6 and 9.x (fixed dates -> deterministic).

## Optional (external dependency)

`generate-glyphs-demo.tcl` renders real TTF/OTF text via `fillcontours`, using
the third-party Glyphs package (it pulls in its own Bezier/BContour) and a font
file. NOT part of the suite; not run by the scripts above. Glyphs and the font
each carry their own license. Only a font FILE is required:

    tclsh generate-glyphs-demo.tcl /path/to/arial.ttf
    tclsh generate-glyphs-demo.tcl /path/to/font.otf 48 mytext.utf8 out.png

`generate-month-glyphs-demo.tcl` renders a tumonthpng calendar whose labels come
from a real font (via Glyphs + fillcontours, passed to tumonthpng's -textcmd):

    tclsh generate-month-glyphs-demo.tcl /path/to/arial.ttf ?out.png? ?year? ?month?

`generate-codepage-glyphs-demo.tcl` renders a full 0..255 code page incl. the
real Latin-1 glyphs (via Glyphs + tucodepng's -textcmd):

    tclsh generate-codepage-glyphs-demo.tcl /path/to/arial.ttf
