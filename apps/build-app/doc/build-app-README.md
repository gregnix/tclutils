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

## Tcl/Tk 9 only

`build-app` needs Tcl 9 to run and builds Tcl 9 programs (zipfs is Tcl 9).
Started with Tcl 8.6 it stops with a message.

## Prerequisites

- **Tcl/Tk 9** on the build machine (`wish9.0`), with the packages the apps
  use: tklib (tablelist, scrollutil), sqlite3, tdbc, tdbc::postgres ...
- A **static basekit** per target (BAWT or magicsplat): a `wish` basekit for
  GUI apps, a `tclsh` basekit for command-line apps. The basekit decides the
  platform of the program (a Windows basekit gives an `.exe`).
- A **display** for GUI apps: the prober and the start check open the app
  once. On a server: `xvfb-run -a`.

Nothing is needed on the **target** machine, except native client
libraries a driver loads (`libpq` for PostgreSQL, the Oracle Instant Client).

`apps/bin/` is empty in the repository: run `build-app.tcl` with `wish9.0`, or
build the builder itself first (`build-app-example-builder.md`).

## All tkutils apps at once

```bash
wish9.0 tclutils/apps/build-app/build-tkutils-apps.tcl -basekit /path/basekit-tk
```

builds every app of `tkutils/apps` into `./programs` and ends with a table
(app, size, starts or FAILED). `-tkutils DIR` when tkutils is not next to
tclutils, `-outdir DIR`, `-only {notes-app csv-editor}`; any other option
goes to `build-app` (e.g. `-extlib`). With a Windows basekit the programs get
`.exe` and are not started (they do not run on Linux).

## One app

```bash
wish9.0 tclutils/apps/build-app/build-app.tcl \
    -out notes -basekit /path/basekit-tk \
    -app tkutils/apps/notes-app -main notes_app.tcl \
    -tm tclutils/lib/tm -tm tkutils/lib/tm
```

That is all a tkutils app needs:

- **No `-launch`.** The generated `main.tcl` sets `argv0` to the app script
  and sources it, so the app's own guard
  `if {[file normalize $argv0] eq [file normalize [info script]]}` starts it,
  exactly as with `wish app.tcl`. Command-line arguments arrive in `$argv`.
- **Shared code** in `tkutils/apps/_lib` (e.g. `sqledit` for the SQL
  editors) is bundled when the app's scripts name it; no `-include`.
- **External packages** are found by the prober: it starts the app once and
  bundles what it loaded -- package folders (tablelist via tklib, sqlite3,
  tdbc ...) to `lib/pkgs`, Tcl modules outside the `-tm` trees (e.g.
  `tdbc::sqlite3`) to `lib/tm`. Without `-extlib` it looks where the Tcl
  running `build-app` finds its packages.
- **Start check**: a GUI program is started once with `SMOKE=strict`; it
  then sees only what is inside it (not the Tcl installed on the build
  machine), reports `SMOKE OK` after the window is up and ends. A start
  error is printed and `build-app` exits with 1. `-smoke 0` skips it.

| App | `-main` | bundled besides tclutils/tkutils | target also needs |
|---|---|---|---|
| adressbuch | `adressbuch.tcl` | tklib, sqlite3 | -- |
| csv-editor | `csv_editor.tcl` | tklib | -- |
| knowledge | `knowledge-base.tcl` | tklib, sqlite3, tdbc, tdbc::sqlite3 | -- |
| notes-app | `notes_app.tcl` | tklib | -- |
| sqlite-editor | `sqlite-editor.tcl` | tklib, sqlite3 | -- |
| tdbc-sqlite-editor | `tdbc-sqlite-editor.tcl` | tklib, sqlite3, tdbc, tdbc::sqlite3 | -- |
| postgresql-editor | `postgresql-editor.tcl` | tklib, tdbc, tdbc::postgres | `libpq` |
| oracle-editor | `oracle-editor.tcl` | Oratcl (must be installed to build) | Oracle Instant Client |
| search-replace-tool | `search_replace_tool.tcl` | tklib | -- |
| tkdevtools | `tkdevtools.tcl` | tklib, Thread | -- |
| tkudesigner | `tkudesigner.tcl` | tklib | -- |
| launcher | `launcher.tcl` | tklib | -- |

All but oracle-editor (no Oratcl there) were built and started this way with
Tcl 9.0.4; each program is 3 to 5 MB. The launcher as a program has no
"Apps" submenu: the other apps are not next to it.

## When the program does not start

- **Start it from a terminal** (Windows: `cmd`, then the `.exe`): wish
  shows the error in a window, a terminal also gets the trace. Or build
  again: the start check prints it.
- *"can't find package X"*: X was not bundled. Is X installed for the Tcl
  that runs `build-app`? Else give its folder with `-extlib`. A package the
  app loads only later (when you open a file, connect ...) is not seen by
  the prober: record it in a manifest (below) or `-include DIR=lib/pkgs/DIR`.
- *Nothing happens, no window*: the app was built with an old `-launch`
  that names a proc the app does not have. Leave `-launch` out.
- *"can't find package tclutils::..."*: a `-tm` tree is missing.
- A Windows program built on Linux cannot be started there; copy it to
  Windows and start it from `cmd` once.

## Options

| Option | Meaning |
|---|---|
| `-out FILE` | output program (required) |
| `-basekit FILE` | static Tcl/Tk 9 basekit (required) |
| `-app DIR` | the app's folder (required) |
| `-main FILE` | entry script, relative to `-app` (required) |
| `-kind gui\|cli` | GUI app (default) or command-line app (`tclsh` basekit) |
| `-tm DIR` | module tree to bundle (repeatable) |
| `-extlib DIR` | where the prober looks for packages (repeatable; default: the package folders of the Tcl running `build-app`) |
| `-probe 0\|1` | find the packages the app loads (default 1 for `gui`) |
| `-writemanifest FILE` | probe and also write the found list to FILE |
| `-manifest FILE` | bundle exactly the list in FILE, no probing, no display |
| `-smoke 0\|1` | start the GUI program once after building (default 1) |
| `-include SRC[=DEST]` | copy more into the program (data, icons, a package) |
| `-launch CODE` | Tcl to run after sourcing the entry (only for an app without argv0 guard); then `argv0` is not set |
| `-bootstrap none\|tkutils` | write the `_lib/paths.tcl` shim (default: `tkutils` for GUI apps) |
| `-stdlibfrom basekit\|running\|DIR` | where the standard library comes from (default: the basekit) |
| `-keep 0\|1` | keep the temporary tree for a look inside |

## CLI apps

A command-line app that does its work at source time (find-tclconfig,
build-app itself) needs `-kind cli` and a `tclsh` basekit; its script
becomes `main.tcl`:

```bash
tclsh9.0 tclutils/apps/build-app/build-app.tcl -kind cli \
    -out find-tclconfig -basekit /path/basekit-tcl \
    -app tclutils/apps/find-tclconfig -main find-tclconfig.tcl
```

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

The step-by-step examples in this folder (builder, find-tclconfig,
notes-app, sqlite-editor, postgresql-editor, launcher, explorer,
windows-host) explain the pieces in more depth. Where they still show
`-launch` or `-include .../sqlite-editor=sqlite-editor`, leave those out:
`-launch` is no longer needed and the SQL editors take their shared code
from `_lib/sqledit` by themselves.
