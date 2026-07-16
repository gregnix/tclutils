# Step by step: find-tclconfig as a program

This example builds the dependency-free CLI app `find-tclconfig` into a single
executable — a Tcl 9 zipkit. Because `find-tclconfig` needs no tclutils modules,
it is the simplest case; GUI apps and external packages follow in the other
examples.

## Prerequisites

Two things on the build host — nothing else, no installed Tcl:

1. A static **tcl basekit** (from BAWT or magicsplat), here `basekit-tcl`.
2. The **builder** `bin/build-app-zipkit-linux` (ships in the repo).

Nothing is required on the target machine.

## Step 1 — Lay out the files

We work in `apps/bin/`, where the builder already lives, and drop the basekit
next to it. The app source is one level up, at `../find-tclconfig`.

```bash
cd apps/bin
cp /path/to/basekit-tcl .        # the static tcl basekit
ls
# basekit-tcl  build-app-zipkit-linux
```

## Step 2 — Build

One call. `-kind cli` because it is a console app without Tk; `-out` is the
finished executable's name, `-basekit` the template, `-app`/`-main` point at the
entry script.

```bash
./build-app-zipkit-linux -kind cli -out find-tclconfig \
    -basekit basekit-tcl \
    -app ../find-tclconfig -main find-tclconfig.tcl
```

```
built: find-tclconfig (3178040 bytes)
```

## Step 3 — Check it is self-contained

No `libtcl` reference — Tcl is statically inside the basekit:

```bash
ldd find-tclconfig | grep -i tcl || echo "no libtcl dep"
# no libtcl dep
```

## Step 4 — Run

With `env -i` (a completely empty environment — no `PATH`, no installed Tcl) you
can see the executable really carries everything:

```bash
env -i ./find-tclconfig
```

```
TYP   VER   VERZEICHNIS
------------------------------------------------------------------
Tcl   9.0   /usr/lib/x86_64-linux-gnu/tcl9.0
Tk    9.0   /usr/lib/x86_64-linux-gnu/tk9.0

Brauchbare Paare (gleiche Version fuer Tcl und Tk):
------------------------------------------------------------------

  Tcl/Tk 9.0
    ./configure --with-tcl=/usr/lib/x86_64-linux-gnu/tcl9.0 \
                --with-tk=/usr/lib/x86_64-linux-gnu/tk9.0
```

Done. The file `find-tclconfig` can now be shipped on its own and runs on any
Linux x64 without installation.

## Variant — without the bundled builder

If you prefer the raw script, run it from a basekit. It finds `tuzipfs`
repo-relative and the result is identical:

```bash
./basekit-tcl ../build-app/build-app.tcl -kind cli -out find-tclconfig \
    -basekit basekit-tcl -app ../find-tclconfig -main find-tclconfig.tcl
# built: find-tclconfig (3178040 bytes)
```

If the script runs from a *different* directory (not `apps/build-app/`), pass the
module path explicitly: `-tm ../../lib/tm`.

## Optional — build a Windows .exe on Linux

Only change the basekit: pass the Windows basekit as `-basekit`. The standard
library is taken from that basekit by default, so it matches the Windows target.

```bash
cp /path/to/basekit-win-tcl.exe .
./build-app-zipkit-linux -kind cli -out find-tclconfig.exe \
    -basekit basekit-win-tcl.exe \
    -app ../find-tclconfig -main find-tclconfig.tcl
# built: find-tclconfig.exe (3873710 bytes)

file find-tclconfig.exe
# find-tclconfig.exe: Zip archive, with extra data prepended  (valid PE + appended ZIP)
```

The `.exe` can only be run on Windows; it is built without Windows.

## What happens

`build-app` assembles a VFS tree (the app as `main.tcl`, plus `tcl_library`
copied from the basekit) and calls `zipfs mkimg`, which prepends the basekit's
bytes and appends the tree as a ZIP. On startup Tcl 9 mounts that archive at
`//zipfs:/app` and runs `main.tcl`. Details in `docs/guide/build-app.md`.
