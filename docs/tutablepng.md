# tclutils::tutablepng

Render tabular data to a PNG table image using the pure-Tcl drawing layer
`tclutils::tupngdraw` (no Tk, no external packages). An export adapter: data in,
a styled table image out.

## API

```tcl
package require tclutils::tutablepng

::tclutils::tutablepng::render rows ?options?   ;# -> PNG bytes
::tclutils::tutablepng::write  file rows ?options?  ;# -> file
# write leaves an existing file if the write fails (0.3).
```

`rows` is a list of rows; each row is a list of cell strings. Short rows are
padded with empty cells; the column count is the widest row.

Options (defaults): `-header 1` (style the first row), `-align l` (a single
`l|c|r` or a per-column list), `-scale 1` (font scale), `-padding 6` (cell
padding px, integer >= 0), `-spacing 1` (px between glyphs, integer >= 0), `-background white`,
`-gridcolor {180 180 185}`, `-textcolor {25 25 25}`, `-headerbg {230 230 238}`,
`-headertext {0 0 0}`, `-zebra {}` (alt-row colour, empty = off), `-border 1`
(grid lines). Colours take any tupngdraw form (name, `#rrggbb`, `RRGGBB`,
`{r g b}`, `{r g b a}`).

Cell text is drawn exactly as given: a cell that looks like a number (`4.80`,
`1e3`, `0x1F`, `010`) is not normalised.

```tcl
set rows {
    {Name      Qty Price}
    {Apples     12  3.40}
    {Pears        4  2.10}
}
tclutils::tutablepng::write table.png $rows \
    -header 1 -align {l r r} -zebra {245 245 248}
```

## CLI

```bash
tclsh bin/tutablepng.tcl out.png -d , -header 1 -align "l r r" data.csv
cat data.tsv | tclsh bin/tutablepng.tcl out.png
```

Reads delimited rows (default delimiter: tab) from a file or stdin and writes a
PNG table.

## Errors

| Error code | Cause |
|---|---|
| `{TCLUTILS TUTABLEPNG EMPTY}` | no rows, or rows without cells |
| `{TCLUTILS TUTABLEPNG ALIGN}` | `-align` entry not `l`, `c`, `r` |
| `{TCLUTILS TUTABLEPNG PADDING}` | `-padding` not an integer >= 0 |
| `{TCLUTILS TUTABLEPNG SPACING}` | `-spacing` not an integer >= 0 |
| `{TCLUTILS COMMON ...}` | `-header`/`-border` not boolean, `-scale` not >= 1 |

## Notes

Column widths are derived from the fixed 6x8 font, so they are exact for the
embedded glyphs. Grid lines are drawn crisp (no antialiasing); cell text is the
bitmap font. For large tables prefer a modest `-scale`.
