# Step by step: sqlite-editor (with a C-extension)

This example builds `sqlite-editor` — a GUI app that needs **real external
packages**: the C-extension `sqlite3` and the `tablelist` widget set. That brings
in the role of the **prober** and the `-extlib` option, and shows how a
C-extension is loaded from the zipkit at runtime. If you do not know the simpler
examples yet, start with `EXAMPLE-find-tclconfig.md` and `EXAMPLE-notes-app.md`.

## Prerequisites

1. A static **wish basekit**, here `basekit-tk`.
2. The **builder** `bin/build-app-zipkit-linux`.
3. The module trees `tclutils/lib/tm` and `tkutils/lib/tm`.
4. The **external packages** in a directory the prober searches — the `sqlite3`
   and `tablelist` install, e.g. the `lib/` of your Tcl 9 install or a BAWT
   package collection. In this example: `/opt/tcl9/lib`.

For the prober the build host needs a display — headless via `xvfb-run`.

## Step 1 — Lay out the files

As in the GUI example, work in `tclutils/apps/bin/` with `tclutils/` and
`tkutils/` as siblings:

```bash
cd tclutils/apps/bin
cp /path/to/basekit-tk .
```

The app has several files (`sqledit-core.tcl`, `be-sqlite.tcl`,
`sqledit-form.tcl`, `sqledit-sheet.tcl` …) — `build-app` copies the whole app
directory, so you only give the directory and the entry script.

## Step 2 — Build

New versus `notes-app`: `-extlib` points at the external package install.
`-launch` also calls `::sqledit::requireDeps`, which loads `sqlite3`.

```bash
xvfb-run -a ./build-app-zipkit-linux -kind gui -out sqlite-editor \
    -basekit "$(pwd)/basekit-tk" \
    -app ../../../tkutils/apps/sqlite-editor -main sqlite-editor.tcl \
    -launch '::sqledit::requireDeps; ::sqledit::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -extlib /opt/tcl9/lib
```

The prober starts the app once and reports the really-loaded external packages:

```
  probe: external package Tablelist_tile 7.11 -- no own path (covered by another bundle)
  probe: external package file::home 1 -- no own path (covered by another bundle)
  probe: external package mwutil 2.25  <- /opt/tcl9/lib/tablelist7.11
  probe: external package sqlite3 3.53.0  <- /opt/tcl9/lib/sqlite3.53.0
built: sqlite-editor (8279547 bytes)
```

It recognized `sqlite3` and `tablelist7.11` as package roots and bundles exactly
those. (`Tablelist_tile`/`file::home` are alias packages with no own path — they
are already inside the `tablelist7.11` bundle.)

Note `-basekit "$(pwd)/basekit-tk"` as an **absolute** path: the prober starts
the basekit with `exec`, and `exec` does not search the current directory.

## Step 3 — What was bundled

The prober already reported it in Step 2; you can inspect the image like this
(headless via `xvfb-run`, with `exit`, because the wish basekit would otherwise
enter the event loop):

```bash
xvfb-run -a ./basekit-tk <<'EOF'
zipfs mount [pwd]/sqlite-editor s
puts [glob -tails -directory //zipfs:/s/lib/pkgs *]
exit 0
EOF
# tablelist7.11 sqlite3.53.0
```

## Step 4 — Self-contained, and a smoke test

No reference to `libtcl`, `libtk`, or `libsqlite` — the C-extension is inside the
image too:

```bash
ldd sqlite-editor | grep -iE 'tcl|tk9|sqlite' || echo "no libtcl/libtk/libsqlite dep"
# no libtcl/libtk/libsqlite dep

SMOKE=1 xvfb-run -a ./sqlite-editor
# SMOKE OK: children=6 title=SQLite Editor - (not connected)
```

That the smoke test passes is itself proof that `requireDeps` loaded the
C-extension `sqlite3` **from the zipkit**.

## Step 5 — Run

```bash
./sqlite-editor            # empty window
./sqlite-editor my.db      # or open a database directly
```

## How the C-extension loads from the zipkit

The operating system cannot load a shared library directly out of a `zipfs`.
Tcl's `load` command handles it: on first access it copies the `.so` to a
temporary directory and loads it from there. For the app this is transparent —
`package require sqlite3` works in the zipkit just as usual.

## Important: C-extensions are platform-specific

The bundled `libtcl9sqlite3.53.0.so` is a **Linux** binary. A Windows build needs
the **Windows** variant (`.dll`) of the same package. When cross-building:

- `-basekit` sets the interpreter's platform (as before).
- `-extlib` must point at the packages **of the target platform** — the Windows
  `sqlite3`/`tablelist` install, not the Linux version.
- Cross-platform probing is not possible, so build with `-probe 0` and supply the
  external packages via `-extlib` (target platform).

Pure Tcl/Tk apps (like `notes-app`) do not have this problem — only apps with
C-extensions. For `find-tclconfig` and `notes-app`, a basekit swap is still
enough for a cross-build.

## What happens

`build-app` assembles the VFS tree (app directory, module trees, `tcl_library`/
`tk_library` copied from the basekit, the prober-found external packages under
`lib/pkgs/`, a bootstrap shim, a generated `main.tcl`) and calls `zipfs mkimg`.
Details in `docs/guide/build-app.md`.
