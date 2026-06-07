# tclutils::tupngpad

Normalise a set of (transparent) PNGs to a uniform size. Typical use: object
cut-outs saved as transparent PNGs, each cropped to its own tight bounding box.
`tupngpad` brings them all to one common size, centres each one, keeps a margin
around the content, and flattens transparency onto a background colour (e.g.
white). Pure Tcl, no Tk and no external packages; the pixel work pairs with
`tclutils::tupng` / `tclutils::tupngdraw`.

## API

```tcl
package require tclutils::tupngpad

# normalise every PNG in $files into /out, all the same size
tclutils::tupngpad::batch $files /out -margin 4 -background white
```

### File-level

`tupngpad::batch files outdir ?options?` — read each PNG in `files`, optionally
trim it to its content, then pad every image to one common size and write the
result into `outdir` (same base name). Returns the list of written paths.

Options:

- `-margin N` — empty space kept around the content, in pixels (default `4`).
- `-background COLOR` — colour the formerly transparent area is flattened onto
  (default `white`; same colour forms as `tupngdraw`).
- `-trim BOOL` — crop each input to its content bounding box first (default `1`).
- `-align A` — placement of the content in the padded canvas: `center`
  (default), `nw`, `n`, `ne`, `w`, `e`, `sw`, `s`, `se`.
- `-square BOOL` — force a square output (default `0`).
- `-size {W H}` — force the inner content area; default is the maximum content
  size found across all inputs.

### Pixel-level primitives

These operate on an RGBA pixel buffer (`rgba`) of width `w` and height `h`, as
produced/consumed by the `tupng` layer:

- `tupngpad::bbox rgba w h` — return the content bounding box `{x0 y0 x1 y1}`
  (the non-transparent extent).
- `tupngpad::trim rgba w h` — crop the buffer to its bounding box.
- `tupngpad::padTo rgba w h tw th ?options?` — centre/place the content inside a
  `tw`×`th` canvas. Options: `-background COLOR` (default `white`), `-align A`
  (as above), `-filter {}`.

## Notes

- Pure Tcl, no Tk, no external dependencies (TclOO/`clock`/core only).
- Designed to chain with `tupng`/`tupngdraw`: decode → `trim`/`padTo` → encode.
