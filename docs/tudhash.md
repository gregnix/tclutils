# tclutils::tudhash

A perceptual **difference hash** (dHash) in pure Tcl, Tk-free. dHash turns an
image into a 64-bit fingerprint so that visually similar images get similar
fingerprints: two pictures are "the same" when the **Hamming distance** between
their hashes is small. This finds near-duplicate scans/photos (rescaled,
recompressed, slightly adjusted) that an exact byte hash (`sha256`, `xxhash`)
would never match.

Pure Tcl, 8.6+ / 9.x. The bit convention matches the common dHash (e.g. python
`imagehash.dhash`), verified against it.

## Commands

```tcl
tudhash::fromGray w h grayList         ;# -> 16 hex chars (64-bit hash)
tudhash::fromRGB  w h rgbList          ;# -> 16 hex chars
tudhash::distance hexA hexB            ;# -> 0..64 (Hamming distance)
tudhash::similar  hexA hexB ?maxDist?  ;# -> bool (default maxDist 10)
```

- `grayList`: `w*h` integers 0..255, row-major.
- `rgbList`: `w*h*3` integers 0..255, row-major (`r g b r g b ...`); reduced to
  luminance internally.

The image may be any size — it is box-averaged down to 9×8 and each pixel is
compared with its right neighbour, row by row, giving 8×8 = 64 bits.

## This is the Tk-free core

`tudhash` deliberately works on a **pixel grid**, not on image files. Decoding
an image into that grid is a separate, format-dependent step. Keeping it out of
`tclutils` is what lets this module stay Tk-free. Get the grid however suits the
caller:

**With Tk (photo + the `Img` package for JPEG/TIFF/…):** best for a GUI or a
client that already has Tk. Belongs in a `tkutils` app, not here:

```tcl
package require Tk
# package require Img   ;# for JPEG/TIFF/etc.
proc imageToGray {path} {
    set img [image create photo -file $path]
    set w [image width $img]; set h [image height $img]
    set gray {}
    for {set y 0} {$y < $h} {incr y} {
        for {set x 0} {$x < $w} {incr x} {
            lassign [$img get $x $y] r g b
            lappend gray [expr {(77*$r + 150*$g + 29*$b) >> 8}]
        }
    }
    image delete $img
    return [list $w $h $gray]
}
lassign [imageToGray scan.png] w h gray
set hash [tudhash::fromGray $w $h $gray]
```

**With an external tool** (headless server, no Tk): let `convert` (ImageMagick)
or `pnmscale` produce a small grayscale PGM/raw and read the bytes. Any route
that yields `w`, `h` and the gray values works.

## Example

```tcl
package require tclutils::tudhash
namespace import ::tclutils::tudhash::*

set a [fromGray $w1 $h1 $gray1]
set b [fromGray $w2 $h2 $gray2]
if {[similar $a $b]} { puts "near-duplicate (distance [distance $a $b])" }
```

Typical thresholds on the 64-bit hash: **0** identical reduction, **≤ 5** almost
certainly the same picture, **≤ 10** likely related, **> 15** different. Tune
`maxDist` to the corpus.

## dHash vs. exact hashes

`xxhash`/`sha256` answer "are these the exact same bytes"; `tudhash` answers "do
these look like the same image". A re-saved JPEG has a different `sha256` but the
same (or a very close) dHash. Use the byte hash first for exact dedup, then
`tudhash` to catch the visual near-duplicates that survived.

## Errors

Error code `{TCLUTILS TUDHASH <REASON>}`:

| REASON | When |
|--------|------|
| `DIM` | width/height not positive integers |
| `DATA` | grayList/rgbList has the wrong number of values |
| `HASH` | a hash passed to `distance`/`similar` is not 16 hex chars |

## Testing

`tests/tudhash.test` checks the bit convention against a real 9×8 reduction from
`imagehash`, the all-ones/all-zeros gradients, the distance/similar helpers, the
RGB→gray path and the down-scaler. Set `TCLUTILS_TM` and run with `tclsh`
(passes on 8.6 and 9.0).
