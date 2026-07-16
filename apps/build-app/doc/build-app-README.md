# build-app (turn apps into standalone Tcl 9 programs)

Turns an app under `tclutils/apps/` or `tkutils/apps/` into a **single
executable** — a Tcl 9 *zipkit*: a static Tcl/Tk 9 interpreter with an appended
ZIP holding the app, its modules, and the standard library. The result runs with
no installed Tcl, no tclutils, no extra files — copy and run.

The tool itself is only a thin orchestrator; the real work is done by the image
primitives in `tclutils::tuzipfs` (`rcopy`, `copyStdlib`, `mkimg`). For how a
zipkit works in detail, see `docs/guide/build-app.md`.

## Why

End users should get a program they double-click — not a Tcl install plus module
paths plus a launch script. A zipkit packs everything into one file: no
unpacking, no temp directory, no dependency trouble, and the user need not know
the program is written in Tcl.

## Two forms

The tool comes in two forms with the same options:

- **Bundled zipkit** `apps/bin/build-app-zipkit-linux` — carries `tuzipfs`
  embedded. On the build host it needs **nothing** but itself and the basekits.
  This is the normal case.
- **Raw script** `apps/build-app/build-app.tcl` — run it from a basekit; it
  finds `tuzipfs` repo-relative (or via `-tm`).

## Prerequisites

Static Tcl/Tk 9 **basekits** (from BAWT or magicsplat), per target:

- a `tclsh` basekit for CLI apps,
- a `wish` basekit for GUI apps.

Nothing is required on the **target** machine.

## Usage

```bash
# CLI app (Tk-free) onto the tcl basekit
./build-app-zipkit-linux -kind cli \
    -out find-tclconfig -basekit basekit-tcl \
    -app ../find-tclconfig -main find-tclconfig.tcl

# GUI app onto the wish basekit
./build-app-zipkit-linux -kind gui \
    -out notes -basekit basekit-tk \
    -app ../../../tkutils/apps/notes-app -main notes_app.tcl \
    -launch '::notesapp::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -extlib /opt/tcl9/lib
```

Always quote `-launch` — curly braces do not quote in the shell.

## Options

| Option | Meaning |
|---|---|
| `-out FILE` | output executable (required) |
| `-basekit FILE` | static Tcl/Tk 9 basekit template (required) |
| `-kind cli\|gui` | console app (tclsh) or GUI app (wish) (required) |
| `-app DIR` | the app's source directory (required) |
| `-main FILE` | entry script, relative to `-app` (required) |
| `-launch CODE` | Tcl to start the app (e.g. `{::notesapp::buildApp .}`); omit for scripts that run at source time (CLI) |
| `-tm DIR` | module tm tree to bundle (repeatable) |
| `-include SRC[=DEST]` | copy extra content into the VFS at DEST (default: basename); for shared code an app sources from a sibling dir, or data files/icons (repeatable) |
| `-extlib DIR` | search root for external pkgIndex packages (for the prober; repeatable) |
| `-probe 0\|1` | determine the real dependency closure (default: 1 for `gui`) |
| `-writemanifest FILE` | run the prober and also write the found dependency list to FILE |
| `-manifest FILE` | bundle exactly the packages listed in FILE — no probing, no display (reproducible builds) |
| `-stdlibfrom basekit\|running\|DIR` | source of the standard library (default: the target `-basekit`) |
| `-bootstrap none\|tkutils` | whether to emit a `_lib/paths.tcl` shim |
| `-keep 0\|1` | keep the temporary VFS tree for inspection |

## CLI vs GUI

For **GUI** apps `build-app` generates a `main.tcl` that loads `Tk`, builds the
app (`-launch`), and keeps the event loop open (`vwait forever` +
`WM_DELETE_WINDOW → exit`) — a zipkit does not reproduce wish's implicit main
loop. For **CLI** apps that run at source time, the entry script becomes the
`main.tcl` directly.

## Cross-platform

The output platform is decided entirely by `-basekit`. A Windows `.exe` can be
built on Linux: pass the Windows basekit as `-basekit`. The standard library is
taken from that same basekit by default (`-stdlibfrom basekit`), so it always
matches the target — even when the builder itself runs on another basekit.

## The prober

Rather than guessing dependencies statically from `package require` (which
over-includes, since many requires are lazy), `build-app` runs the app once in
the target basekit and bundles only the packages that were **actually loaded**.
Modules from tclutils/tkutils come via `-tm`; external pkgIndex packages
(sqlite3, tdbc, tablelist …) are found under the `-extlib` roots.

## Reproducible builds: dependency manifests

The prober's result is just a list of external package directories, and you can
record it. Run the prober once and write the list:

```bash
build-app … -extlib /opt/tcl9/lib -writemanifest deps.txt
```

`deps.txt` is a plain, editable list (one install-directory basename per line,
`#` comments allowed). Later — on a build server, in CI, or without a display —
build straight from it, skipping the prober entirely:

```bash
build-app … -extlib /opt/tcl9/lib -manifest deps.txt
```

`-manifest` resolves each name under the `-extlib` roots, so the same list works
on any machine with the same package layout. This is also the list you would ship
if you distribute an app as scripts plus a "install these packages" note rather
than as a self-contained zipkit. (Native client libraries such as `libpq` are not
Tcl packages, so they are never in the manifest — they remain a target-system
dependency either way.)

## Worked examples

In increasing difficulty (see this folder / `docs/guide/`):

1. **builder** — build `build-app` itself (bootstrap).
2. **find-tclconfig** — a dependency-free CLI app.
3. **notes-app** — a pure-Tk GUI app.
4. **sqlite-editor** — a GUI app with a self-contained C-extension.
5. **postgresql-editor** — shared code (`-include`) and a native driver whose
   client library must be on the target.
6. **windows-host** — running the whole chain on Windows.

## Build reference for the bundled apps

Run from `apps/bin/` with `tclutils/` and `tkutils/` as siblings. `-basekit` is
given as an **absolute** path (the prober `exec`s it, and `exec` does not search
the current directory). GUI apps here share the same common options:

```
-basekit "$(pwd)/basekit-tk" -tm ../../lib/tm -tm ../../../tkutils/lib/tm -extlib /opt/tcl9/lib
```

The table lists only what differs per app; the CLI app uses `basekit-tcl` and no
module trees.

| App | kind | entry option | external packages bundled | `-include` | target also needs | size |
|---|---|---|---|---|---|---|
| find-tclconfig | cli | — (runs at source) | — | — | — | 3.2 MB |
| notes-app | gui | `-launch '::notesapp::buildApp .'` | — | — | — | 5.6 MB |
| search-replace-tool | gui | `-launch '::srtool::buildGui'` | — | — | — | 5.6 MB |
| tkdevtools | gui | `-launch '::tkdevtools::buildApp .'` | tablelist | — | — | 6.4 MB |
| tkudesigner | gui | `-launch '::tkudesigner::buildApp .'` | tablelist, scrollutil | — | — | 6.8 MB |
| sqlite-editor | gui | `-launch '::sqledit::requireDeps; ::sqledit::buildApp .'` | sqlite3, tablelist | — | — | 8.3 MB |
| postgresql-editor | gui | `-launch '::sqledit::requireDeps; ::sqledit::buildApp .'` | tdbc, tdbc::postgres, tablelist | `sqlite-editor` | `libpq` | 6.5 MB |
| oracle-editor | gui | `-launch '::sqledit::requireDeps; ::sqledit::buildApp .'` | Oratcl | `sqlite-editor` | Oracle Instant Client | — |

`-main` per app: `find-tclconfig.tcl`, `notes_app.tcl`,
`search_replace_tool.tcl`, `tkdevtools.tcl`, `tkudesigner.tcl`,
`sqlite-editor.tcl`, `postgresql-editor.tcl`, `oracle-editor.tcl`. `-include`
values are `../../../tkutils/apps/sqlite-editor=sqlite-editor`.

Two things worth noting:

- All the bundled GUI apps now expose a `buildApp` entry proc, so they package
  with `-launch '::app::buildApp .'` and none needs a special flag. `-bootstrap
  tkutils` without `-launch` remains available for a foreign app that builds its
  UI at source time and has no entry proc: it forces the GUI `main.tcl` (load Tk,
  set the module path, run the event loop) while only sourcing the app.
- `postgresql-editor` and `oracle-editor` are launchers over the shared
  `sqlite-editor` core, hence `-include`; their native drivers (`libpq`,
  Oracle Instant Client) are system libraries that must be present on the target
  — see `EXAMPLE-postgresql-editor.md`.

Sizes and the SMOKE checks are from real builds in a Tcl 9.0.4 sandbox;
`oracle-editor` was not built there (no `Oratcl`), so its row is the derived
recipe.

### Full commands

Copy-paste, run from `apps/bin/` (with the builder and basekits present):

```bash
# find-tclconfig (CLI)
./build-app-zipkit-linux -kind cli -out find-tclconfig -basekit basekit-tcl \
    -app ../find-tclconfig -main find-tclconfig.tcl

# notes-app
xvfb-run -a ./build-app-zipkit-linux -kind gui -out notes-app -basekit "$(pwd)/basekit-tk" \
    -app ../../../tkutils/apps/notes-app -main notes_app.tcl \
    -launch '::notesapp::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm -extlib /opt/tcl9/lib

# search-replace-tool
xvfb-run -a ./build-app-zipkit-linux -kind gui -out search-replace-tool -basekit "$(pwd)/basekit-tk" \
    -app ../../../tkutils/apps/search-replace-tool -main search_replace_tool.tcl \
    -launch '::srtool::buildGui' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm -extlib /opt/tcl9/lib

# tkdevtools
xvfb-run -a ./build-app-zipkit-linux -kind gui -out tkdevtools -basekit "$(pwd)/basekit-tk" \
    -app ../../../tkutils/apps/tkdevtools -main tkdevtools.tcl \
    -launch '::tkdevtools::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm -extlib /opt/tcl9/lib

# tkudesigner
xvfb-run -a ./build-app-zipkit-linux -kind gui -out tkudesigner -basekit "$(pwd)/basekit-tk" \
    -app ../../../tkutils/apps/tkudesigner -main tkudesigner.tcl \
    -launch '::tkudesigner::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm -extlib /opt/tcl9/lib

# sqlite-editor (C-extension sqlite3)
xvfb-run -a ./build-app-zipkit-linux -kind gui -out sqlite-editor -basekit "$(pwd)/basekit-tk" \
    -app ../../../tkutils/apps/sqlite-editor -main sqlite-editor.tcl \
    -launch '::sqledit::requireDeps; ::sqledit::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm -extlib /opt/tcl9/lib

# postgresql-editor (shared core via -include; needs libpq on the target)
xvfb-run -a ./build-app-zipkit-linux -kind gui -out postgresql-editor -basekit "$(pwd)/basekit-tk" \
    -app ../../../tkutils/apps/postgresql-editor -main postgresql-editor.tcl \
    -launch '::sqledit::requireDeps; ::sqledit::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm -extlib /opt/tcl9/lib \
    -include ../../../tkutils/apps/sqlite-editor=sqlite-editor

# oracle-editor (needs Oratcl + Oracle Instant Client; -extlib must resolve Oratcl,
# or build with -probe 0 and bundle Oratcl yourself)
xvfb-run -a ./build-app-zipkit-linux -kind gui -out oracle-editor -basekit "$(pwd)/basekit-tk" \
    -app ../../../tkutils/apps/oracle-editor -main oracle-editor.tcl \
    -launch '::sqledit::requireDeps; ::sqledit::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm -extlib /opt/tcl9/lib \
    -include ../../../tkutils/apps/sqlite-editor=sqlite-editor
```

On a machine with a real display, drop `xvfb-run -a`. To build without running the
prober (e.g. no display, or dependencies already known), add `-probe 0`.
