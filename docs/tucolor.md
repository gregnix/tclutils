# tclutils::tucolor

Named-color database and conversions: resolve color names / hex / RGB triples to
RGB, convert to hex and HSV, and find the nearest named color. The name table
(CSS3 / X11 standard colors, 148 entries) is **embedded**, so the module is pure
Tcl and **GUI-free** — no Tk / X11 needed at runtime. The table was generated
from Tk's `winfo rgb`, so values match X11/Tk exactly.

## Package

```tcl
package require tclutils::tucolor 0.1
```

## Commands

```tcl
::tclutils::tucolor::rgb     color       ;# -> {r g b}   (0..255 each)
::tclutils::tucolor::hex     color       ;# -> #rrggbb
::tclutils::tucolor::names                ;# -> sorted list of known names
::tclutils::tucolor::exists  name        ;# -> 0 | 1
::tclutils::tucolor::nearest color       ;# -> nearest known color name
::tclutils::tucolor::toHsv   color       ;# -> {h s v}   (h 0..360, s/v 0..100)
::tclutils::tucolor::fromHsv {h s v}     ;# -> {r g b}
```

`color` accepts a known name, `#rgb`, `#rrggbb`, or a `{r g b}` triple (0..255).

## Usage

```tcl
package require tclutils::tucolor
namespace import ::tclutils::tucolor::*

rgb red                 ;# -> 255 0 0
rgb cornflowerblue      ;# -> 100 149 237
rgb #f80                ;# -> 255 136 0   (short hex expands)
hex {255 136 0}         ;# -> #ff8800
nearest #fe0000         ;# -> red
toHsv steelblue         ;# -> 207 61 71
fromHsv {120 100 100}   ;# -> 0 255 0
```

## Notes

- Names are matched case-insensitively. `names` returns the 148 CSS3/X11 keywords.
- `nearest` uses Euclidean distance in RGB space — good enough for snapping an
  arbitrary color to a named one, not a perceptual match.
- HSV is the common hexcone model; round-tripping `toHsv`/`fromHsv` may differ by
  one unit per channel due to integer rounding.
- Being GUI-free, it complements `tuterm` (resolve any color name → RGB for
  24-bit ANSI), `tupng`/`tupngdraw` and `tusvg`.

## Error codes

`-errorcode {TCLUTILS TUCOLOR <REASON>}` (`NAME`).
