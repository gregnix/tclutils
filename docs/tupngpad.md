# tclutils::tupngpad

Normalise a set of (transparent) PNGs to a uniform size. Typical use: object
cut-outs saved as transparent PNGs, each cropped to its own tight bounding box.
`tupngpad` brings them all to one common size, centres each one, keeps a margin
around the content, and flattens transparency onto a background colour (e.g.
white). Pure Tcl, no Tk and no external packages; the pixel work pairs with
`tclutils::tupng` / `tclutils::tupngdraw`. `batch` leaves an existing output
file if the write fails (0.3).

## API

```tcl
package require tclutils::tupngpad

# normalise every PNG in $files into /out, all the same size
tclutils::tupngpad::batch $files /out -margin 4 -background white
```

### File-level

`tupngpad::batch files outdir ?options?` — read each PNG in `files`, optionally
trim it to its content, then pad every image to one common size and write the
result into `outdir` (same base name). Returns a dict
`{size {tw th} files {in1 out1 in2 out2 ...}}`: the common output size and the
input/output paths in pairs. All options are checked before any file is read.

Options:

- `-margin N` — empty space kept around the content, in pixels (default `4`).
- `-background COLOR` — colour the formerly transparent area is flattened onto
  (default `white`; same colour forms as `tupngdraw`).
- `-trim BOOL` — crop each input to its content bounding box first (default `1`).
- `-align A` — placement of the content in the padded canvas: `center`
  (default), `nw`, `n`, `ne`, `w`, `e`, `sw`, `s`, `se`. Any other value is an
  error (`{TCLUTILS COMMON VALUE -align}`, the message lists the allowed ones).
- `-square BOOL` — force a square output (default `0`).
- `-size {W H}` — force the inner content area (positive integers); default is
  the maximum content size found across all inputs.

### Pixel-level primitives

These operate on an RGBA pixel buffer (`rgba`) of width `w` and height `h`, as
produced/consumed by the `tupng` layer:

- `tupngpad::bbox rgba w h` — return the content bounding box `{x0 y0 x1 y1}`
  (the non-transparent extent).
- `tupngpad::trim rgba w h` — crop the buffer to its bounding box.
- `tupngpad::padTo rgba w h tw th ?options?` — centre/place the content inside a
  `tw`×`th` canvas and return PNG bytes. Options: `-background COLOR` (default
  `white`), `-align A` (as above), `-filter {}` (empty = `up`).

Semi-transparent pixels are composited source-over onto the background
(`tupngdraw paste`): on an opaque background they become opaque blends, on a
transparent background (`-background transparent`) they keep their colour and
alpha.

## Errors

| Error code | Cause |
|---|---|
| `{TCLUTILS TUPNGPAD MARGIN}` | `-margin` not an integer >= 0 |
| `{TCLUTILS TUPNGPAD TRIM}` | `-trim` not a boolean |
| `{TCLUTILS TUPNGPAD SQUARE}` | `-square` not a boolean |
| `{TCLUTILS TUPNGPAD SIZE}` | `-size` not empty or `{W H}` with integers >= 1 |
| `{TCLUTILS COMMON VALUE -align}` | unknown `-align` |

Errors from reading and decoding the files (`open`, `tupng::decode`) pass
through unchanged.

## Notes

- Pure Tcl, no Tk, no external dependencies (TclOO/`clock`/core only).
- Designed to chain with `tupng`/`tupngdraw`: decode → `trim`/`padTo` → encode.
