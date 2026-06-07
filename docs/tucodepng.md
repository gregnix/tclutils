# tclutils::tucodepng

Render a character-code table (a classic code-page grid) to a PNG. Data comes
from `tclutils::tucode` (`lookup`); drawing from `tclutils::tupngdraw`. Pure Tcl.

    package require tclutils::tucodepng
    tclutils::tucodepng::write ascii.png 0 127 -title "ASCII 0-127" -shownames 1
    set png [tclutils::tucodepng::latin1 -shownames 1]   ;# 128..255 -> PNG bytes

## API

- `render from to ?opts?` -> PNG bytes (range within 0..255).
- `write file from to ?opts?` -> writes the PNG, returns the filename.
- `ascii ?opts?` (0..127), `latin1 ?opts?` (128..255), `all ?opts?` (0..255).

Each cell shows the hex code (top), the glyph (centre) and, with `-shownames`,
the name (bottom). Control codes (0..31, 127) show their abbreviation
(NUL, ESC, ...); 32 shows "SP".

## Options

`-columns N` (default 16), `-scale N` (default 2), `-theme default|dark|light`,
`-showcode 0|1` (default 1), `-shownames 0|1` (default 0), `-title TEXT`,
`-textcmd CMD`.

## Real glyphs for Latin-1 (-textcmd)

The built-in 6x8 bitmap font covers ASCII (and German umlauts), so 0..127
renders fully dependency-free. For the real Latin-1 glyphs (128..255) pass a
`-textcmd` that fills outline glyphs from a real font (Glyphs + tupngdraw
`fillcontours`); hex codes, names and control abbreviations always use the
bitmap font. The command is called `{*}$CMD img x y w h char color` per printable
cell -- same hook as tumonthpng. See examples/generate-codepage-glyphs-demo.tcl.
