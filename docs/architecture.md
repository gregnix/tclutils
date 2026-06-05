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
|   |-- tucrc   |-- tuhash    |-- tustrings |-- tuiconv |-- tucode
|   |-- tubase32|-- tuimage   `-- tupng
|
|-- data / serialization
|   |-- tucsv   |-- tujson  |-- tuxml   |-- tunumfmt `-- tusqlite
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
|   |-- tudate  |-- tuurl   |-- tuuuid  |-- tudav   |-- tufetch
|   `-- tusparql
|
|-- calendar / recurrence
|   |-- tuical  |-- turrule |-- tuholiday `-- tucal
|
|-- events / registry
|   |-- tuevent |-- turegistry `-- tulog
|
|-- strings / validation
|   |-- tustr   `-- tuvalidate
|
|-- lists / dicts
|   |-- tulist  `-- tudict
|
|-- math / tables
|   |-- tumath  `-- tutable
|
`-- archive
    |-- tuzip   `-- tuzipfs
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
detector/encoder (`tuimage`, `tupng`) live here too.

## Data and serialization

Format readers/writers/encoders: `tucsv`, `tujson` (parser + encoder), `tuxml`,
`tunumfmt`, plus `tusqlite` — NULL-safe `insert`/`rows`/`value` helpers over a
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

- `tufetch`: tiny HTTP(S) client (`get`/`download`, GET/POST); native
  `http`+`tls`, otherwise curl/wget via `auto_execok`.
- `tudav`: minimal WebDAV/CardDAV/CalDAV client on `http`(+`tls`).
- `tusparql`: thin SPARQL client (`query`/`ask`) composed from `tufetch`,
  `tuurl`, and `tujson` — no transport or parsing logic of its own.

## Calendar and recurrence

`tuical` (cross-listed with Records/PIM), `turrule` (iCalendar RRULE expansion),
`tuholiday` (Easter computus + nationwide German holidays), and `tucal`
(cross-listed with Document helpers; cal-like text calendars).

## Events, strings, lists, math, archive

The remaining small layers: app glue (`tuevent` pub/sub, `turegistry` service
locator, `tulog` leveled logger); string helpers (`tustr`, `tuvalidate`);
structure helpers (`tulist`, `tudict`); numeric/table helpers (`tumath`,
`tutable`); and ZIP handling (`tuzip` byte-controlled create/read for ODF/OOXML
containers, `tuzipfs` the Tcl 9 ZipFS wrapper that reports unavailable on 8.6).
