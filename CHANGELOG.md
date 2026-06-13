# Changelog

## 0.53.0

Changes since 0.41.0. Many modules were added; the library remains pure Tcl
(Tcl core only; `zlib` optional for ZIP) and runs on Tcl 8.6 and Tcl 9.x.

- PNG / image family: `tupng` (PNG read/write), `tupngdraw` (canvas-style
  drawing to PNG), `tupngpad`, `tucodepng`, `tutablepng`, `tumonthpng`,
  `tusvg` (SVG generation), and `tuimage` (image type/dimension/data-URI
  helpers).
- Date / web / IDs: `tudate`, `tuurl`, `tuuuid`, `tudav` (WebDAV client),
  `tufetch` (tiny HTTP(S) `get`/`download`, native `http`+`tls` else
  curl/wget), and `tusparql` (thin SPARQL client). The net helpers are
  optional and not dependency-free.
- Events / logging / registry: `tuevent`, `tulog`, `turegistry`.
- Calendar / recurrence: `turrule` (RRULE expansion), `tuholiday`.
- Strings / validation: `tustr`, `tuvalidate`, `tupagespec` (page-range
  spec parser, e.g. `1-3,5,7-`).
- Lists / dicts / math / tables: `tulist`, `tudict`, `tumath`, `tutable`.
- Stream / filesystem: `tuopen` (open files/URLs with the OS handler) and
  `tuexe` (locate external executables across bundled dirs and PATH).
- Data / records: `tusqlite` (TDBC/sqlite helper, optional), `tubookmark`.
- Text filters / encoding: `tucsplit`, `tufmt`, `tubase32`.
- Module hygiene: per-module `test` / `doc` / `man` across all 96 umbrella
  modules; `tcltest` suite green on Tcl 8.6 and Tcl 9.x.
- Recommended pairing: tclutils 0.53.0 + tkutils 0.40.0.

## 0.41.0

Initial public release.

- Pure-Tcl utility library, no external dependencies (Tcl core only; `zlib`
  optional for ZIP). Runs on Tcl 8.6 and Tcl 9.x.
- Coreutils-style text filters (cat, tac, rev, nl, seq, head, tail, wc, sort,
  tsort, uniq, cut, paste, join, comm, split, fold, expand, shuf, column, pr,
  tr, sed-subset, grep, awk, xargs).
- Compare/patch: `tucmp`, `tudiff`, `tupatch`.
- Binary / encoding / checksums: `tubin`, `tuhexdump`, `tuod`, `tuhexedit`,
  `tubase64`, `tucrc`, `tustrings`, `tuiconv`, `tucode`, and `tuhash`
  (SHA-256 / SHA-1 / MD5, verified against the standard vectors).
- Data / serialization: `tucsv` (RFC-4180 quoting, multiline, BOM strip,
  lenient `-strict 0`), `tujson` (parse / `parseTyped` / `fromJson` and the
  `toJson` encoder with builders), `tuxml`, `tunumfmt`.
- Stream / filesystem: `tufile`, `tufind`, `tustat`, `tutee`, `tupath`
  (normalize/clean/relative/commonPath/readlink), `tusize` (du-like).
- Fuzzy search: `tufuzzy`, `tuagrep`.
- Records / PIM (read + edit): `tunotes`, `tuical`, `tuini`, `tuvcard`,
  `tuldif`.
- Document helpers: `tumd`, `tupdf`, `tuodf`, `tucal`.
- Archive: `tuzip`, `tuzipfs`.
- Thin CLI wrappers in `bin/` and runnable demos in `examples/`.
- Full `tcltest` suite, green on Tcl 8.6 and Tcl 9.x.
