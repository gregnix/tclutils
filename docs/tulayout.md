# tclutils::tulayout

Page layout helpers for document block designers and renderers. Pure Tcl, no
dependencies. Coordinates are in millimetres with origin at the top-left of the
page.

## API

```tcl
tulayout::pageSize paper ?portrait|landscape?   ;# -> {widthMm heightMm}
tulayout::mmToPx mm scale
tulayout::pxToMm px scale
tulayout::snap mm ?-grid 5?
tulayout::isAutoY block                         ;# y==0 or lockedY
tulayout::normalizeBlock block ?-defaults dict?
tulayout::validateBlocks blocks                   ;# id -> block dict
tulayout::ensureBlocks blocks definitions         ;# merge with definitions
tulayout::blockOrder blocks ?definitions?
tulayout::blockRect block ?-height mm?
tulayout::mergeBlocks base preset ?-keys {x y w show}?
tulayout::mergeLayout target preset ?-keys {x y w show}?
tulayout::fitScale pageWmm pageHmm viewWpx viewHpx ?-marginPx 20?
tulayout::defaultBlockKeys
```

### Block dict

Each block is a dict. Common keys:

| Key | Meaning |
|-----|---------|
| `label` | Human label in the designer |
| `x`, `y`, `w`, `h` | Position/size in mm |
| `show` | `1` visible, `0` hidden |
| `lockedY` | `1` = auto vertical placement (`y` stays `0`) |

`normalizeBlock` keeps only `label x y w h show lockedY`, takes missing keys
from `-defaults` (default `x 0 y 0 w 40 h 8 show 1`), turns `x y w h` into
doubles and `show` into `0`/`1`. A non-numeric `x`/`y`/`w`/`h` or a
non-boolean `show` raises `{TCLUTILS TULAYOUT VALUE}` (`bad <key> '<value>'`).

`validateBlocks` normalises every block and checks it: `blocks` must be a
non-empty dict (`BLOCKS`), ids must not be empty (`BLOCKID`), values must be
numbers (`VALUE`, `block '<id>': bad <key> '<value>'`) and `x`, `y`, `w`, `h`
must not be negative (`VALUE`).

`ensureBlocks` merges a (possibly empty) `blocks` dict with `definitions`
(id -> block dict). For a block in `blocks` a missing key comes from its
definition, then from the standard values above; a value in the block wins.
An id that only appears in `definitions` is created from the definition alone.
The result is checked like `validateBlocks`. With an empty `blocks` every
block comes from the definitions:

```tcl
tulayout::ensureBlocks {kopf {x 20}} {kopf {w 170 h 15}}
;# -> kopf {x 20.0 y 0.0 w 170.0 h 15.0 show 1}
tulayout::ensureBlocks {} {kopf {w 170 h 15}}
;# -> kopf {w 170.0 h 15.0}
```

`mergeBlocks` copies only the keys listed in `-keys` (default `{x y w show}`) from
`preset` into `base` for matching block ids. This is the usual “apply layout
preset to a live document” operation.

`mergeLayout` expects full layout dicts with a `blocks` sub-dict:

```tcl
set doc [tulayout::mergeLayout $doc $preset]
```

### Papers

Supported names: `a4` (210 × 297), `a5` (148 × 210), `letter` (216 × 279),
case-insensitive. A free size in mm is given as a two-element list
`{width height}` or as `WxH` / `WXH` (e.g. `54x56`, `80.5X200`); both parts
must be positive numbers. Only `landscape` swaps width and height. Unknown
names, malformed sizes such as `1.2.3x5` and non-positive sizes raise
`{TCLUTILS TULAYOUT PAPER}`.

### Options

All commands with options (`snap`, `normalizeBlock`, `blockRect`,
`mergeBlocks`, `mergeLayout`, `fitScale`) reject an unknown option or an
option without a value with `{TCLUTILS TULAYOUT OPTION}`.

### Error codes

| Code | Raised by |
|------|-----------|
| `{TCLUTILS TULAYOUT PAPER}` | `pageSize`: unknown paper, malformed or non-positive size |
| `{TCLUTILS TULAYOUT SCALE}` | `mmToPx`, `pxToMm`: scale not a positive number |
| `{TCLUTILS TULAYOUT GRID}` | `snap`: grid not a positive number |
| `{TCLUTILS TULAYOUT OPTION}` | unknown option, option without a value |
| `{TCLUTILS TULAYOUT BLOCKS}` | `validateBlocks`: `blocks` empty or not a dict; `ensureBlocks`: `blocks`, `definitions` or a block not a dict |
| `{TCLUTILS TULAYOUT BLOCKID}` | empty block id |
| `{TCLUTILS TULAYOUT VALUE}` | non-numeric `x y w h`, non-boolean `show`, negative `x y w h` |
| `{TCLUTILS TULAYOUT LAYOUT}` | `mergeLayout`: target or preset without a `blocks` key |
| `{TCLUTILS TULAYOUT VIEWPORT}` | `fitScale`: viewport minus twice the margin not positive |

### Example

```tcl
package require tclutils::tulayout

set blocks {
    header {label Header x 20 y 30 w 170 h 15 show 1}
    table  {label Table  x 20 y 0  w 170 h 40 show 1}
}
set preset {
    header {x 25 show 1}
}
set merged [tulayout::mergeBlocks $blocks $preset]
```

## Tests

```bash
tclsh tests/tulayout.test
tclsh examples/demo-tulayout.tcl
```

## See also

`tkutils::tkulayoutcanvas` — Tk megawidget built on this engine.
