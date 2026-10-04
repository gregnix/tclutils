# tclutils::tupkgfinder

Inspect how Tcl resolves packages: known versions, their `ifneeded` scripts and
source locations, which version is active versus shadowed, the relevant search
paths (`auto_path`, `tcl::tm::path`), and an optional filesystem search by glob
pattern. `candidates` and `shadows` (0.2) list every copy of a package on the
search paths -- also a second copy with the same version, which the package
database never shows because it keeps one `ifneeded` per version. Useful for
"about / diagnostics" views. Pure Tcl, no GUI.

## API

```tcl
::tclutils::tupkgfinder::paths
::tclutils::tupkgfinder::versions       packageName
::tclutils::tupkgfinder::pkgInfo        packageName
::tclutils::tupkgfinder::which          packageName
::tclutils::tupkgfinder::report         packageName
::tclutils::tupkgfinder::findFileSystem pattern ?roots?
::tclutils::tupkgfinder::findFileSystem pattern ?-roots {d ...}? ?-maxdepth N? \
        ?-followlinks 0|1? ?-maxfiles N? ?-excludeDirs {name ...}?
::tclutils::tupkgfinder::candidates     ?-pattern glob? ?-tmpaths list? ?-autopath list?
::tclutils::tupkgfinder::shadows        ?-pattern glob? ?-all 0|1? ?-tmpaths list? ?-autopath list?
```

- `paths` — dict `{auto_path {pos path ...} tm_path {pos path ...}}`.
- `versions` — versions known to the package database (those with an `ifneeded`
  entry; note the running interpreter's own `Tcl` has none).
- `pkgInfo` — dict with `package`, `versions`, `ifneeded` per version, and the
  source `locations` extracted from each `ifneeded` script.
- `which` — resolution view: `found` (version/path/script), `activeVersion`,
  `activePath`, and `shadowed` paths. Determining the active version calls
  `package require`, which loads the package as a side effect.
- `report` — a human-readable multi-line diagnostic for one package.
- `findFileSystem` — glob the filesystem for matching files. Without `-roots` a
  platform default set is scanned (can be slow); bound it with `-maxdepth` /
  `-maxfiles`.
- `candidates` — list of dicts `{package version kind path}` for every copy:
  kind `tm` (path = the `.tm` file in a module path; `a/b/x-1.0.tm` is
  `a::b::x`) or `pkgIndex` (path = a `pkgIndex.tcl` in an `auto_path`
  directory or one level below, as Tcl searches). Only literal
  `package ifneeded NAME VERSION` lines are seen. `-tmpaths` / `-autopath`
  replace the interpreter's paths.
- `shadows` — one dict per package with more than one copy (every package
  with `-all 1`): `{package active activePath duplicate candidates}`. Each
  candidate carries a `status`: `active` (the copy `package require` takes),
  `same version` (a second copy of the active version that is not used --
  the case to look at), or `other version`. `duplicate` is 1 when a version
  has more than one copy. For a package whose copies are not all registered
  yet, an unsatisfiable `package require` runs Tcl's unknown handlers first;
  nothing is loaded.

```tcl
puts [::tclutils::tupkgfinder::report tablelist]
set w [::tclutils::tupkgfinder::which Img]
puts "active: [dict get $w activePath]  shadowed: [dict get $w shadowed]"
::tclutils::tupkgfinder::findFileSystem *pdf4tcl* -roots [list $root] -maxdepth 4
foreach d [::tclutils::tupkgfinder::shadows] {
    if {[dict get $d duplicate]} { puts "twice: [dict get $d package]" }
}
```

## Errors

Carries `{TCLUTILS TUPKGFINDER OPTION}` for an unknown option or a bad
option/value count in `findFileSystem`, `candidates` and `shadows`.

Version note: 0.2 adds `candidates` and `shadows`; the 0.1 commands are
unchanged.

## Demo

```bash
tclsh examples/demo-tupkgfinder.tcl
```
