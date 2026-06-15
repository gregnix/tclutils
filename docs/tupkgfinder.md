# tclutils::tupkgfinder

Inspect how Tcl resolves packages: known versions, their `ifneeded` scripts and
source locations, which version is active versus shadowed, the relevant search
paths (`auto_path`, `tcl::tm::path`), and an optional filesystem search by glob
pattern. Useful for "about / diagnostics" views. Pure Tcl, no GUI.

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

```tcl
puts [::tclutils::tupkgfinder::report tablelist]
set w [::tclutils::tupkgfinder::which Img]
puts "active: [dict get $w activePath]  shadowed: [dict get $w shadowed]"
::tclutils::tupkgfinder::findFileSystem *pdf4tcl* -roots [list $root] -maxdepth 4
```

## Errors

Carries `{TCLUTILS TUPKGFINDER OPTION}` for an unknown option or a bad
option/value count in `findFileSystem`.

## Demo

```bash
tclsh examples/demo-tupkgfinder.tcl
```
