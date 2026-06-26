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
tulayout::ensureBlocks blocks definitions         ;# fill missing ids
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

`mergeBlocks` copies only the keys listed in `-keys` (default `{x y w show}`) from
`preset` into `base` for matching block ids. This is the usual “apply layout
preset to a live document” operation.

`mergeLayout` expects full layout dicts with a `blocks` sub-dict:

```tcl
set doc [tulayout::mergeLayout $doc $preset]
```

### Papers

Supported names: `a4`, `a5`, `letter`. Unknown paper raises
`{TCLUTILS TULAYOUT PAPER}`.

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
