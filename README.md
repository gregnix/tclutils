# tclutils 0.53.0

`tclutils` is a collection of small, pure-Tcl utility modules — coreutils-style
text filters, data-format parsers/encoders, binary and checksum helpers, and a
few document/PIM helpers. It has **no external dependencies** (Tcl core only,
optionally `zlib` for ZIP) and runs on **Tcl 8.6 and Tcl 9.x**.

It is intentionally split from [`tkutils`](../tkutils-0.28.0/) (the Tk GUI
widgets) so that console, server and CI use never requires Tk.

## Install

Put the library's module directory on the Tcl module path, then require the
umbrella package (loads all core modules) or a single module:

```tcl
::tcl::tm::path add /path/to/tclutils-0.53.0/lib/tm
package require tclutils          ;# umbrella: all core modules
package require tclutils::tucsv    ;# or just one module
```

`tools/setup.tcl` / `tools/setup.md` show a drop-in path setup.

## Module overview

Detailed scope per module is in [`docs/module-status.md`](docs/module-status.md);
the Unix-tool mapping is in [`docs/coreutils-mapping.md`](docs/coreutils-mapping.md).

| Category | Modules |
|----------|---------|
| Text / coreutils filters | `tucat` `tutac` `turev` `tunl` `tuseq` `tuhead` `tutail` `tuwc` `tusort` `tutsort` `tuuniq` `tucut` `tupaste` `tujoin` `tucomm` `tucsplit` `tusplit` `tufold` `tuexpand` `tushuf` `tucolumn` `tupr` `tutr` `tused` `tugrep` `tuawk` `tuxargs` `tufmt` |
| Compare / patch | `tucmp` `tudiff` `tupatch` |
| Binary / encoding / checksums | `tubin` `tuhexdump` `tuod` `tuhexedit` `tubase64` `tucrc` `tuhash` `tustrings` `tuiconv` `tucode` `tubase32` `tuimage` `tupng` |
| Data / serialization | `tucsv` `tujson` `tuxml` `tunumfmt` `tusqlite` |
| Stream / filesystem | `tufile` `tufind` `tustat` `tutee` `tupath` `tusize` `tuopen` |
| Fuzzy search | `tufuzzy` `tuagrep` |
| Records / PIM | `tunotes` `tuical` `tuini` `tuvcard` `tuldif` `tubookmark` |
| Document helpers | `tumd` `tupdf` `tuodf` `tucal` |
| Date / web / IDs | `tudate` `tuurl` `tuuuid` `tudav` `tufetch` `tusparql` |
| Calendar / recurrence | `tuical` `turrule` `tuholiday` `tucal` |
| Events / registry | `tuevent` `turegistry` `tulog` |
| Strings / validation | `tustr` `tuvalidate` |
| Lists / dicts | `tulist` `tudict` |
| Math / tables | `tumath` `tutable` |
| Archive | `tuzip` `tuzipfs` |
| Core | `common` |

Highlights: `tucsv` (RFC-4180 quoting, multiline, BOM strip, lenient `-strict 0`),
`tujson` (parse/`parseTyped`/`fromJson` **and** the `toJson` encoder with
`str`/`num`/`bool`/`null`/`obj`/`arr` builders), `tuhash` (pure-Tcl
SHA-256/SHA-1/MD5 verified against the standard vectors).

The optional net/data helpers `tudav`, `tufetch`, `tusparql` and `tusqlite` are
the exception to "no external dependencies": they need the `tls` package (or a
`curl`/`wget` binary) for HTTPS, respectively an `sqlite3` build — only at the
point of use, so the umbrella still loads without them.

## Command-line wrappers

Thin CLI front-ends live in `bin/` — see [`docs/cli.md`](docs/cli.md).

## Output formats

`tclutils` writes text, CSV (`tucsv`) and JSON (`tujson`) directly. Routes to
PDF and OpenDocument (.odt/.ods/.odg) via the companion libraries `pdf4tcl`,
`pdf4tcllib`, `odf` and `docir` are sketched in
[`docs/todo-output.md`](docs/todo-output.md).

## Testing

Each module has a `tests/*.test` file; run the whole suite with:

```bash
tclsh tests/all.tcl </dev/null
```

The suite passes on both Tcl 8.6 and Tcl 9.x.

## Conventions & status

- House rules and module scope: [`docs/module-status.md`](docs/module-status.md)
- Roadmap and backlog: [`docs/roadmap.md`](docs/roadmap.md)
- Architecture notes: [`docs/architecture.md`](docs/architecture.md)

## License

MIT — see `LICENSE`.
