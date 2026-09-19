# tclutils architecture

`tclutils` is a Tcllib-style collection of portable utilities written in pure
Tcl. It is intentionally not a full clone of GNU coreutils. The modules are
small library packages with tests, examples, and documentation.

The grouping below matches the top-level [`README.md`](../README.md) and
[`module-status.md`](module-status.md): the same 16 categories, with `tuical`
and `tucal` cross-listed exactly as the README lists them.

## Layer overview

```text
common  (Core: shared layer)
|
|-- text / coreutils filters
|   |-- tucat   |-- tutac   |-- turev   |-- tunl    |-- tuseq
|   |-- tuhead  |-- tutail  |-- tuwc    |-- tusort  |-- tutsort
|   |-- tuuniq  |-- tucut   |-- tupaste |-- tujoin  |-- tucomm
|   |-- tucsplit|-- tusplit |-- tufold  |-- tuexpand|-- tushuf
|   |-- tucolumn|-- tupr    |-- tutr    |-- tused   |-- tugrep
|   |-- tuawk   |-- tuxargs `-- tufmt
|
|-- compare / patch
|   |-- tucmp   |-- tudiff  `-- tupatch
|
|-- binary / encoding / checksums
|   |-- tubin   |-- tuhexdump |-- tuod   |-- tuhexedit |-- tubase64
|   |-- tucrc   |-- tuhash    |-- tuxxhash  |-- tudhash  |-- tustrings
|   |-- tuiconv |-- tucode
|   |-- tubase32|-- tuimage   |-- tupng   |-- tupngdraw  |-- tutablepng
|   |-- tumonthpng |-- tucodepng |-- tupngpad `-- tusvg
|
|-- diagrams (Mermaid-compatible)
|   |-- tuflow  |-- tudiagram |-- tustate |-- tuer    |-- tuclass
|   |-- turequirement |-- tumindmap |-- tuc4 |-- tublock |-- tugit
|   |-- tupie   |-- tuxychart |-- tuquadrant |-- tujourney |-- tutimeline
|   |-- tusankey |-- tugantt `-- tusequence
|
|-- data / serialization
|   |-- tucsv   |-- tujson  |-- tuxml   |-- tunumfmt |-- tusqlite
|   |-- tummdb  `-- tutdbc (own package require)
|
|-- stream / filesystem
|   |-- tufile  |-- tufind  |-- tustat  |-- tutee   |-- tupath
|   |-- tusize  `-- tuopen
|
|-- fuzzy search
|   |-- tufuzzy `-- tuagrep
|
|-- records / PIM
|   |-- tunotes |-- tuical  |-- tuini   |-- tuvcard |-- tuldif
|   `-- tubookmark
|
|-- document helpers
|   |-- tumd    |-- tupdf   |-- tuodf   `-- tucal
|
|-- date / web / IDs
|   |-- tudate  |-- tuurl   |-- tuuuid  |-- tudav   |-- tufetch |-- tuexe
|   |-- tusparql |-- tupostgrest `-- tuhttps (HTTPS policy of the three clients)
|
|-- storage providers
|   |-- tuprovider (local)  |-- tuprovider::zip  |-- tuprovider::dav
|   |-- tuprovider::ftp     `-- tuprovider::sftp (own package require)
|
|-- calendar / recurrence
|   |-- tuical  |-- turrule |-- tuholiday `-- tucal
|
|-- events / registry
|   |-- tuevent |-- turegistry `-- tulog
|
|-- strings / validation
|   |-- tustr   |-- tuvalidate `-- tupagespec
|
|-- lists / dicts
|   |-- tulist  `-- tudict
|
|-- math / tables
|   |-- tumath  `-- tutable
|
|-- archive
|   |-- tuzip   `-- tuzipfs
|
`-- icons
    `-- tuico
```

(`tuical` and `tucal` appear under two categories, mirroring the README's
navigation grouping.)

## Shared layer (Core)

`common` contains reusable helpers for file I/O, binary I/O, line splitting,
delimited splitting, and option parsing. It is not a user-facing command; every
other module builds on it.

## Text and coreutils filters

Line-oriented tools shaped after the GNU/POSIX utilities (grep/sed/sort/cut/paste
/join/comm/fold/tr/fmt, the small filters nl/seq/rev/tac/expand/shuf/column/pr,
the `tsort`/`numfmt`-style helpers, and the `awk`/`xargs` processors). Each is a
deliberate subset, not a full reimplementation.

## Compare and patch

`tucmp` (byte equality), `tudiff` (line LCS, unified/context, directory diff),
and `tupatch` (apply/reverse unified diffs).

## Binary, encoding, and checksums

`tubin` is the reusable binary primitive layer (unsigned readers/packers, hex,
ASCII-safe rendering, byte-list helpers); `tuhexdump`, `tuod`, `tuhexedit`, and
`tuzip` build on it. The encode/checksum wrappers (`tubase64`, `tubase32`,
`tucrc`, `tuhash`, `tuiconv`), the byte-table reference `tucode`, and the image
detector/encoder (`tuimage`, `tupng`) live here too. On top of `tupng` sits a
small pure-Tcl PNG drawing/generation layer: `tupngdraw` (a 2D surface — shapes,
text, glyph fills) and the export adapters built on it — `tutablepng` (tabular
data → table image), `tumonthpng` (month/quarter/year calendar → PNG, mirroring
the monthcanvas look), `tucodepng` (ASCII/Latin-1 code-page chart → PNG), plus
`tupngpad` (normalise transparent PNG cut-outs to a uniform, padded size).
Alongside the raster path, `tusvg` is the **vector** generator: a pure-Tcl SVG
builder (shapes/paths/text/gradients/groups) with a library of ~110 named
toolbar icons, used by `tkutils::tkuicon`.

## Diagrams

A Mermaid-compatible diagram subsystem sits on top of the raster/vector layer.
`tuflow` is the facade: it reads a fenced-code diagram source, detects the kind
and dispatches. Graph-shaped types become a `tudiagram` model via a dedicated
parser (`tustate`, `tuer`, `tuclass`, `turequirement`, `tumindmap`, `tuc4`,
`tublock`, `tugit`, plus tuflow's own flowchart parser); `tudiagram` then lays
the graph out (layered layout, shapes, crow's-foot end-marks) and draws it.
Non-graph types own a self-contained 2D renderer (`tupie`, `tuxychart`,
`tuquadrant`, `tujourney`, `tutimeline`, `tusankey`, `tugantt`, `tusequence`). Both paths render through the shared
`tusvg` / `tupngdraw` canvas protocol, so SVG and PNG output stay congruent.
`docir::diagram` wires this subsystem into the docir sinks.

## Data and serialization

Format readers/writers/encoders: `tucsv`, `tujson` (parser + encoder), `tuxml`,
`tunumfmt`, `tummdb` (a pure-Tcl MaxMind `.mmdb` geolocation reader), plus `tusqlite` — NULL-safe `insert`/`rows`/`value` helpers over a
caller-supplied `sqlite3` handle (it does not load `sqlite3` itself).

## Stream and filesystem

`tufile` (type detection), `tufind`, `tustat`, `tutee`, `tupath`, `tusize`, and
`tuopen` (open with the OS default app).

## Fuzzy search

`tufuzzy` provides edit-distance/approximate-match primitives; `tuagrep` builds
approximate grep on top of it while following the shape of `tugrep`.

## Records / PIM and document helpers

The PIM interchange formats are readers/writers like the data layer, but for
contact/calendar/config data: `tunotes` (a value-based hierarchical note store),
`tuical` (iCalendar), `tuini`, `tuvcard`, `tuldif`, and `tubookmark`. The
document helpers `tumd`, `tupdf`, `tuodf`, and `tucal` are intentionally small
inspectors/generators, not full engines.

## Date, web, and identifiers

`tudate` (clock-based date math), `tuurl` (RFC 3986), `tuuuid` (v4/v7), and the
web clients. The web clients are the only **not dependency-free** modules:

- `tuexe`: locate external executables across bundled dirs and PATH (candidate names, platform extensions); `find`/`all`/`exists`.
- `tufetch`: tiny HTTP(S) client (`get`/`download`, GET/POST); native
  `http`+`tls`, otherwise curl/wget via `auto_execok`.
- `tudav`: minimal WebDAV/CardDAV/CalDAV client on `http`(+`tls`).
- `tusparql`: thin SPARQL client (`query`/`ask`) composed from `tufetch`,
  `tuurl`, and `tujson` — no transport or parsing logic of its own.
- `tupostgrest`: minimal PostgREST client (URL/query/JSON body, bearer token,
  JSON response to dicts).
- `tuhttps`: the one HTTPS policy of `tufetch`, `tudav` and `tupostgrest`
  (since 0.63.0). It builds a verifying `::tls::socket` prefix and registers
  `https` only for the duration of a request, restoring the previous
  registration afterwards. `::http::register` is global to the interpreter;
  before 0.63.0 each client registered its own policy and never undid it, so
  one `tufetch` call left the whole process unverified.

## Storage providers

`tuprovider` is one small storage API — `list`, `stat`, `get`, `put`,
`delete`, `mkdir`, `move`, and `caps` to ask what a backend can do — over the
local filesystem. Backends plug in as `tuprovider::zip`, `::dav` (over
`tudav`), `::ftp` (tcllib's ftp client, loaded when a connection is opened)
and `::sftp` (the OpenSSH `sftp` client; not in the umbrella). Consumers see
paths with children and do not know where the bytes live.

This is the model layer of the Explorer stack:

```
tclutils  tuprovider (+ backends)          model
tkutils   tkufiletree/-list/-path/-preview  view
ctrlutils cufileops/cumonitor/cuundo/…     controller
```

A capability a backend lacks is reported by `caps` and not offered by the
controllers (a ZIP is read-only), rather than failing when used.

## Calendar and recurrence

`tuical` (cross-listed with Records/PIM), `turrule` (iCalendar RRULE expansion),
`tuholiday` (Easter computus + nationwide German holidays), and `tucal`
(cross-listed with Document helpers; cal-like text calendars).

## Events, strings, lists, math, archive

The remaining small layers: app glue (`tuevent` pub/sub, `turegistry` service
locator, `tulog` leveled logger); string helpers (`tustr`, `tuvalidate`, `tupagespec`);
structure helpers (`tulist`, `tudict`); numeric/table helpers (`tumath`,
`tutable`); and ZIP handling (`tuzip` byte-controlled create/read for ODF/OOXML
containers, `tuzipfs` the Tcl 9 ZipFS wrapper that reports unavailable on 8.6).
Since 0.2 `tuzipfs` also carries the zipkit image primitives (`rcopy`,
`copyStdlib`, `mkimg`, `buildImage`) that back the `build-app` application — a
standalone-application builder for Tcl 9; see `docs/guide/build-app-guide.md`.

`tuico` writes and reads Windows `.ico` containers with PNG payloads, so icons
keep their alpha channel; it needs no Tk. It complements tklib's `ico`, which
extracts icons from ICO/EXE/DLL but cannot write a true 32bpp alpha icon from a
Tk image.
