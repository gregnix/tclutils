# Step by step: notes-app (GUI) as a program

This example builds the GUI app `notes-app` from the tkutils repo into a single
executable. Compared with the CLI example (`find-tclconfig`), three things are
added: a **wish** basekit, bundling the module trees (`-tm`), and a launch
command (`-launch`). If you do not know the CLI example yet, start with
`EXAMPLE-find-tclconfig.md`.

## Prerequisites

On the build host — nothing else, no installed Tcl:

1. A static **wish basekit** (Tk included), here `basekit-tk`.
2. The **builder** `bin/build-app-zipkit-linux`.
3. The module trees the app needs: `tclutils/lib/tm` and `tkutils/lib/tm`.

For the **prober** (see below) the build host needs an X display — headless via
`xvfb-run`. Nothing is required on the target machine.

## Step 1 — Lay out the files

Assume the usual side-by-side layout: `tclutils/` and `tkutils/` as sibling
directories. We work in `tclutils/apps/bin/` and drop the wish basekit there.

```bash
cd tclutils/apps/bin
cp /path/to/basekit-tk .
ls
# basekit-tk  build-app-zipkit-linux
```

Relative paths from here: the app is at `../../../tkutils/apps/notes-app`, the
module trees at `../../lib/tm` (tclutils) and `../../../tkutils/lib/tm`.

## Step 2 — Build

`xvfb-run -a` gives the build a virtual display (the prober starts the app
briefly — more on that below). New options versus the CLI case:

- `-kind gui` — a GUI app, so wish basekit and an event loop in `main.tcl`.
- `-launch '::notesapp::buildApp .'` — the call that builds the UI. Needed
  because sourcing the app only defines its procedures; its built-in "run as
  main script?" check does not fire inside a zipkit.
- `-tm …` — the module trees `tkutils` and `tclutils::tunotes` are bundled from
  (twice, one per repo).
- `-extlib /opt/tcl9/lib` — search root for external pkgIndex packages, in case
  the prober finds any (for notes-app: none).

```bash
xvfb-run -a ./build-app-zipkit-linux -kind gui -out notes-app \
    -basekit basekit-tk \
    -app ../../../tkutils/apps/notes-app -main notes_app.tcl \
    -launch '::notesapp::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -extlib /opt/tcl9/lib
```

```
built: notes-app (5620756 bytes)
```

Always double-quote `-launch` — curly braces do not quote in the shell, so the
space would otherwise split the value.

## Step 3 — Check it is self-contained

```bash
ldd notes-app | grep -iE 'tcl|tk9' || echo "no libtcl/libtk dep"
# no libtcl/libtk dep
```

## Step 4 — Headless smoke test

The generated `main.tcl` has a smoke mode: with the variable `SMOKE` set it
builds the UI, reports it, and exits. Good for CI without a real screen.

```bash
SMOKE=1 xvfb-run -a ./notes-app
# SMOKE OK: children=5 title=Notes - Untitled
```

## Step 5 — Run

On a machine with a display, just start it:

```bash
./notes-app
```

The window opens and stays open (the generated `main.tcl` holds the event loop
with `vwait forever`; closing the window quits the program). The file `notes-app`
can be shipped on its own and runs on any Linux x64 without installation.

## Why xvfb-run?

It is not the finished program that needs the display, but the **prober**
*during* the build: it starts the app once in the target basekit to determine
the really-loaded dependencies — and a GUI app needs Tk with a display for that.
On a machine with a screen you can drop `xvfb-run`. If you already know the
dependencies (for notes-app it is only the tm trees), disable the prober with
`-probe 0` and build with no display at all:

```bash
./build-app-zipkit-linux -kind gui -out notes-app -probe 0 \
    -basekit basekit-tk \
    -app ../../../tkutils/apps/notes-app -main notes_app.tcl \
    -launch '::notesapp::buildApp .' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm
```

## Windows .exe

As with the CLI example: pass the **Windows wish basekit** as `-basekit`, `-out
notes-app.exe`. The Tk standard library comes from that basekit by default, so it
matches the Windows target. The prober would then run on the Windows basekit —
cross-platform probing is not possible, so build with `-probe 0` (dependencies
known from the Linux run).

## What happens

`build-app` assembles a VFS tree: the app under `app/`, the module trees under
`lib/tm/`, `tcl_library` and `tk_library` copied from the basekit, a bootstrap
shim `_lib/paths.tcl`, and a generated `main.tcl` that loads Tk, sources the app,
runs `-launch`, and holds the event loop open. Then `zipfs mkimg` appends the
tree to the basekit. Details in `docs/guide/build-app.md`.
