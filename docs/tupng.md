# tclutils::tupng

A pure-Tcl PNG **encoder** -- no Tk, no external packages, only the core `zlib`
command. It is the encode-side companion to `tclutils::tuimage` (which inspects
PNG headers). Writes 8-bit images in four colour types:

| Function | Colour type | Pixel syntax |
|----------|-------------|--------------|
| `encodeRGB` / `writeRGB`         | truecolour (2)        | `RRGGBB` / `#rrggbb` / `{r g b}` |
| `encodeRGBA` / `writeRGBA`       | truecolour+alpha (6)  | `RRGGBBAA` / `{r g b a}` |
| `encodeGray` / `writeGray`       | grayscale (0)         | integer 0..255 |
| `encodeIndexed` / `writeIndexed` | palette (3)           | integer index into palette |

The image model is a list of rows; each row is a list of pixels and all rows
must have equal length. `encode*` return PNG bytes; `write*` write them to a file.

```tcl
set png [tupng::encodeRGB {{FF0000 00FF00} {0000FF FFFFFF}}]
tupng::writeRGBA out.png {{FF0000FF 00FF0080} {0000FF00 FFFFFFFF}} -compression 9
tupng::writeIndexed out.png {FF0000 0000FF00} {{0 1} {1 0}}   ;# entry 1 transparent
```

## Options

- `-compression 0..9` (default 6) -- zlib level.
- `-filter best|none|sub|up|average|paeth` (default `best`). `best` picks a
  per-scanline filter using the minimum-sum-of-absolute-differences heuristic
  (fast); the fixed modes force one filter.

## Notes / limits

Encode only (no decoder). 8-bit depth; no 16-bit and no interlacing. For
indexed images the palette holds 1..256 entries; a palette entry with alpha
< 255 emits a `tRNS` chunk. Truecolour alpha (RGBA) is stored inline (type 6).
Reuses only `tclutils::common` (option parsing) and the core `zlib`.

## Decoding (0.3)

`tupng::decode bytes` and `tupng::readPNG file` reconstruct an 8-bit,
non-interlaced PNG (colour types 0/2/3/4/6) and return a dict:
`width height colortype bitdepth rgba`, where `rgba` is width*height*4
packed bytes (row-major R G B A) -- the inverse of `encodeRGBARaw`, so
encode/decode round-trips byte-exactly. Errors carry
`{TCLUTILS TUPNG DECODE <reason>}` (SIGNATURE, IHDR, BITDEPTH, INTERLACE,
COLORTYPE, IDAT, FILTER). 16-bit and interlaced PNGs are not supported.
