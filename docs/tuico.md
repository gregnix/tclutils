# tclutils::tuico — Windows icon containers

Reads and writes the `.ico` container format. Payloads go in and out as raw
bytes; the module never rasterises anything, so it needs **no Tk** and runs
headless.

```tcl
package require tclutils::tuico 0.1
```

## Why this exists next to tklib's `ico`

tklib ships an `ico` package that reads icons from ICO, EXE, DLL, ICL and BMP
files — useful, and this module does not try to replace it. But its
documentation states two limits that matter for *writing* modern icons:

> There is currently no way to read alpha channel information from 32bpp icons.

> Tk images do not have an alpha channel so the only way to write a true 32bpp
> icon is from a color list. Writing a 32bpp icon from a Tk image is identical
> to writing a 24bpp icon.

Tk photo images **do** have an alpha channel since 8.6, and Tk writes PNG
natively. `tuico` therefore stores **PNG payloads**, which Windows accepts for
icon entries since Vista and which carry alpha as a matter of course.

Rule of thumb: use tklib `ico` to *extract* icons from existing binaries, use
`tuico` to *write* new ones with transparency.

## Commands

All commands are also reachable through the ensemble `tclutils::tuico`.

### `write outFile entries`

Writes an `.ico` file. `entries` is a list of `{size pngData}` pairs, where
`size` is the nominal edge length in pixels (1–256) and `pngData` is a PNG image
as a byte string. Returns the number of bytes written.

Every payload is validated before anything is written, so a rejected call leaves
no partial file behind: it must be a PNG, and its IHDR dimensions must match the
declared size.

```tcl
set entries {}
foreach size {48 16} {
    lappend entries [list $size [readPngSomehow $size]]
}
tclutils::tuico write app.ico $entries
```

### `info icoFile`

Returns a list of dicts, one per entry, with the keys `width`, `height`, `bpp`,
`format` (`png` or `bmp`), `offset` and `length`.

```tcl
foreach entry [tclutils::tuico info app.ico] {
    puts "[dict get $entry width]px [dict get $entry format]"
}
```

### `extract icoFile size ?outFile?`

Returns the raw payload of the entry with the given width. With `outFile` given,
the payload is also written there.

```tcl
tclutils::tuico extract app.ico 256 large.png
```

## Format notes

- A dimension of **0** in the directory means **256**; `write` encodes this and
  `info` decodes it, so callers always see 256.
- Entries are written in the order given. Largest first is conventional.
- BMP (DIB) payloads are **recognised on read** and reported as `format bmp`.
  Writing them is out of scope — PNG covers every Windows version still in use.

## Errors

`errorCode` is always `{TCLUTILS TUICO <REASON>}`:

| Reason | When |
|---|---|
| `NOENTRIES` | empty entry list |
| `TOOMANY` | more than 65535 entries |
| `BADENTRY` | an entry is not a `{size data}` pair |
| `BADSIZE` | size outside 1..256 |
| `BADPNG` | payload is not a PNG |
| `SIZEMISMATCH` | PNG dimensions differ from the declared size |
| `BADFILE` | file is not an `.ico` |
| `TRUNCATED` | directory entry is cut short |
| `NOSUCHSIZE` | `extract` found no entry of that size |
| `READFAILED` / `WRITEFAILED` | file could not be opened |

## Requirements

Tcl 8.6 or later. Nothing else — no Tk, no packages.
