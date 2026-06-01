# Changelog

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
