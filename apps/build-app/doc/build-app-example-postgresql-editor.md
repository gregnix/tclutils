# Step by step: postgresql-editor (shared code + a native driver)

This example builds `postgresql-editor` — the hardest case in the series. It adds
two things over `sqlite-editor`: the launcher reuses **shared code from a sibling
app directory** (handled with `-include`), and it depends on a **native database
driver** (`tdbc::postgres`) whose underlying client library (`libpq`) is a
system dependency the zipkit cannot fully contain. If you are new to the builder,
start with the `find-tclconfig`, `notes-app`, and `sqlite-editor` examples first
(these are in German; this one is in English).

## Prerequisites

On the build host — nothing installed system-wide except:

1. A static **wish basekit**, here `basekit-tk`.
2. The **builder** `bin/build-app-zipkit-linux`.
3. The module trees `tclutils/lib/tm` and `tkutils/lib/tm`.
4. The **external packages** the prober will find: `tdbc` and `tdbc::postgres`,
   plus `tablelist`. Point `-extlib` at where they live (e.g. `/opt/tcl9/lib`).
5. **`libpq`** on the build host, so the prober can actually load
   `tdbc::postgres` (on Debian/Ubuntu: `apt install libpq5`).

The prober needs a display; run it headless with `xvfb-run`.

## Step 1 — Lay out the files

As in the GUI example, work in `tclutils/apps/bin/` with `tclutils/` and
`tkutils/` as siblings, and drop the wish basekit next to the builder:

```bash
cd tclutils/apps/bin
cp /path/to/basekit-tk .
```

The PostgreSQL editor is a thin launcher: it sources the shared GUI
(`sqledit-core.tcl`, `sqledit-form.tcl`, `sqledit-sheet.tcl`) from the sibling
`sqlite-editor/` directory, and only its backend (`be-postgres.tcl`) is its own.

## Step 2 — Build

Two things are new versus `sqlite-editor`:

- `-include …/sqlite-editor=sqlite-editor` copies the sibling directory into the
  image at `//zipfs:/app/sqlite-editor`, so the launcher's `../sqlite-editor`
  reference resolves inside the zipkit.
- `-extlib` must resolve `tdbc::postgres`, and `libpq` must be present so the
  prober can load it.

```bash
xvfb-run -a ./build-app-zipkit-linux -kind gui -out postgresql-editor \
    -basekit "$(pwd)/basekit-tk" \
    -app ../../../tkutils/apps/postgresql-editor -main postgresql-editor.tcl \
    -launch '::sqledit::requireDeps; ::sqledit::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -extlib /opt/tcl9/lib \
    -include ../../../tkutils/apps/sqlite-editor=sqlite-editor
```

```
  probe: external package mwutil 2.25  <- /opt/tcl9/lib/tablelist7.11
  probe: external package tdbc 1.1.13  <- /opt/tcl9/lib/tdbc1.1.13
  probe: external package tdbc::postgres 1.1.13  <- /opt/tcl9/lib/tdbcpostgres1.1.13
built: postgresql-editor (6500847 bytes)
```

## Step 3 — What was bundled

```bash
xvfb-run -a ./basekit-tk <<'EOF'
zipfs mount [pwd]/postgresql-editor s
puts [lsort [glob -tails -directory //zipfs:/s/lib/pkgs *]]
exit 0
EOF
# tablelist7.11 tdbc1.1.13 tdbcpostgres1.1.13
```

## Step 4 — Smoke test

With `libpq` present the editor builds its window; that alone proves the native
driver loaded from the zipkit:

```bash
SMOKE=1 xvfb-run -a ./postgresql-editor
# SMOKE OK: children=6 title=PostgreSQL Editor - (not connected)
```

## Step 5 — Run

```bash
./postgresql-editor          # opens the editor; connect from the GUI
```

## Shared code across apps: `-include`

The launcher sets `set ::sqledit_dir [file join $::pgedit_dir .. sqlite-editor]`
and sources the shared core from there. `-app` only copies one directory, so
without help the shared files are missing in the image. `-include SRC=DEST`
copies extra content into the VFS at a chosen path; here it places
`sqlite-editor/` next to the app so `../sqlite-editor` resolves. Use the same
option for data files, icons, or any shared module tree an app expects at a
relative path.

## The catch: a native driver needs its client library on the target

`tdbc::postgres` is a thin Tcl driver over PostgreSQL's C client library,
`libpq`. The prober bundles the driver package (`tdbcpostgres1.1.13`, including
its `.so`), and Tcl's `load` extracts that `.so` from the zipkit at runtime —
but the driver's own `libpq.so.5` dependency is resolved by the **operating
system's dynamic linker from system paths**, not from the zipfs. The zipkit
therefore cannot contain `libpq`.

The effect is easy to see. Hide `libpq` and the editor reports it cleanly:

```bash
# with libpq hidden:
SMOKE=1 ./postgresql-editor
# sqledit: This editor needs the tdbc::postgres package.
# couldn't load file "libpq.so.5": libpq.so.5: cannot open shared object file: ...
```

So a database-driver zipkit is self-contained **except** for the client library,
which must be installed on the target (Debian/Ubuntu: `apt install libpq5`). This
is inherent to native clients and applies equally to:

- **Oracle** — `tdbc::oracle` needs the Oracle Instant Client libraries.
- **MySQL/MariaDB** — `tdbc::mysql` needs `libmysqlclient` / `libmariadb`.
- **ODBC** — `tdbc::odbc` needs an ODBC driver manager and the target driver.

Pure Tcl/Tk apps (`notes-app`) and apps whose C-extension is self-contained
(`sqlite3`, which has no external client library — it *is* the database) do not
have this dependency. `sqlite-editor` is therefore fully self-contained;
`postgresql-editor` needs `libpq` on the target.

### Cross-platform note

As with any C-extension, the bundled driver `.so` is platform-specific. A Windows
build needs the Windows `tdbc::postgres` package **and** a Windows `libpq.dll` on
the target; point `-extlib` at the Windows packages and build with `-probe 0`
(cross-platform probing is not possible).

## What happens

`build-app` assembles the VFS (the app under `app/`, the included
`sqlite-editor/` core, the module trees, the stdlib copied from the basekit, the
prober-found packages under `lib/pkgs/`, a bootstrap shim, and a generated
`main.tcl`) and calls `zipfs mkimg`. Details in `docs/guide/build-app.md`.
