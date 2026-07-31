# Step by step: launcher (GUI, external packages + Windows .exe) as a program

This example builds the GUI app `launcher` from the tkutils repo into a single
executable — for Linux and, cross-built on the same Linux host, for Windows.
Compared with the `notes-app` example it adds one thing the others do not need:
**external pkgIndex packages** bundled with `-include` (scrollutil for the
scrollable panel, tical for the calendar). If you have not seen a GUI build yet,
start with `build-app-example-notes-app.md`.

## Prerequisites

On the build host — no installed Tcl required:

1. A static **wish basekit** (Tk included). For Linux, a Linux basekit; for the
   Windows build, the **Windows** wish basekit
   (`zipkit-9_0_4-win64-intel-tk.exe`).
2. The **builder** `bin/build-app-zipkit-linux` (or run `build-app.tcl` under a
   Tcl 9 `wish`).
3. The module trees the app needs: `tclutils/lib/tm` and `tkutils/lib/tm`.
4. The external packages the app loads at runtime:
   - **scrollutil** (from tklib) — the scrollable launcher panel.
   - **tical** — the calendar entry with holidays (optional; only if the menu
     uses a `tical`/calendar entry).

   These are pkgIndex packages, not `.tm` modules, so they are **bundled with
   `-include`**, not `-tm`.

For the **prober** a GUI build needs an X display (headless via `xvfb-run`).
Nothing is required on the target machine.

## Step 1 — Lay out the files

The usual side-by-side layout: `tclutils/`, `tkutils/` and `runtimes/` as
sibling directories. We work in `tclutils/apps/build-app/`.

```
github/
  tclutils/  tkutils/  runtimes/
```

Relative paths from `tclutils/apps/build-app/`: the app is at
`../../../tkutils/apps/launcher`, the module trees at `../../lib/tm` (tclutils)
and `../../../tkutils/lib/tm`, the basekits under `../../../runtimes/`.

## Step 2 — Build for Linux

`xvfb-run -a` gives the prober a virtual display. The launcher's own `icon.png`
sits next to `launcher.tcl` and is bundled automatically (build-app copies the
whole `-app` directory), so no `-include` is needed for the icon.

```bash
cd tclutils/apps/build-app
xvfb-run -a wish9.0 build-app.tcl -kind gui -out launcher \
    -basekit ../../../runtimes/zipkit-9_0_4-Linux64-intel-tk \
    -app ../../../tkutils/apps/launcher -main launcher.tcl \
    -launch '::launcherapp::main $argv' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -include /path/to/tklib/modules/scrollutil=pkgs/scrollutil \
    -include /path/to/tical=pkgs/tical
```

```
built: launcher (6933388 bytes)
```

Notes on the options:

- `-launch '::launcherapp::main $argv'` — builds the UI and starts the event
  loop. Always **double-quote** `-launch`; curly braces do not quote in the
  shell, so the space would split the value.
- `-include SRC=DEST` — copies the package directory into the image at
  `DEST`. Using `pkgs/<name>` matches how the app finds bundled packages: at
  startup it adds every `pkgs/*` directory to `auto_path`.
- No `--` before the options. `wish` swallows a `--`, but `tclsh` would pass it
  on to build-app and you would get *"each option needs a value"*.

## Step 3 — Windows .exe (cross-built on Linux)

Pass the **Windows** wish basekit and name the output `.exe`. Two differences
from the Linux build:

- `-stdlibfrom basekit` (the default) — the Tcl/Tk standard library is copied
  from the Windows basekit, so it matches the target. Do **not** use
  `-stdlibfrom running` here (that would copy the Linux host's stdlib).
- `-probe 0` — the prober would have to run the Windows `.exe`, which cannot
  start on Linux (you would see *"probe run failed"*). Turn it off; the
  dependencies are already known.

```bash
wish9.0 build-app.tcl -kind gui -out launcher.exe -probe 0 \
    -basekit ../../../runtimes/zipkit-9_0_4-win64-intel-tk.exe \
    -app ../../../tkutils/apps/launcher -main launcher.tcl \
    -launch '::launcherapp::main $argv' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm \
    -include /path/to/tklib/modules/scrollutil=pkgs/scrollutil \
    -include /path/to/tical=pkgs/tical
```

```
built: launcher.exe (7302007 bytes)
```

No display is needed for this build (the prober is off).

## Step 4 — Check the Linux build is self-contained

```bash
ldd launcher | grep -iE 'tcl|tk9' || echo "no libtcl/libtk dep"
# no libtcl/libtk dep
```

## Step 5 — Run

Linux: `./launcher`. Windows: copy `launcher.exe` to a Windows x64 machine and
double-click it. On first start the launcher writes a small config and points
you at *Edit > Add suggestions…* to fill the menu. The single file can be
shipped on its own and runs without installation.

## Bundling external packages — the key point

The launcher needs two packages that are **not** part of the standard library
and **not** `.tm` modules:

| package    | why                      | how to bundle                         |
|------------|--------------------------|---------------------------------------|
| scrollutil | scrollable panel (tklib) | `-include .../scrollutil=pkgs/scrollutil` |
| tical      | calendar with holidays   | `-include .../tical=pkgs/tical`       |

Give the destination as `pkgs/<name>`; the app's `addBundledPkgs` adds every
`pkgs/*` directory to `auto_path` at startup, so `package require scrollutil`
and `package require tical` then resolve inside the image. If you leave the
`=DEST` off, the directory lands at the image root under its own name and the
app will not find it under `pkgs/` — so always add `=pkgs/<name>`.

If scrollutil is missing the launcher still runs; the panel simply loses
scrolling (it degrades gracefully via `canScroll`). tical is only needed if the
menu contains a calendar/tical entry.

## The .exe file icon

The produced `.exe` keeps the **basekit's** icon; `build-app` does not touch PE
resources. To use your own icon, replace the icon resource after the build (for
example `rcedit-x64.exe launcher.exe --set-icon app.ico`, run under Wine on
Linux) — see `tkutils/apps/launcher/windows-icon.md`. The runtime window/taskbar
icon (`wm iconphoto`, from the bundled `icon.png`) is separate and already set.

## Doing it in the GUI

`tkutils/apps/buildgui/buildgui.tcl` is a GUI front-end for exactly this build.
The preset **"Launcher (Windows cross)"** fills all the fields (kind, launch,
`-tm`, `-probe 0`, `-stdlibfrom basekit`) and pre-lists the scrollutil/tical
includes; you only set the basekit path and, via **From extlib…**, point at your
package library to add scrollutil and tical. See that app's README.

## What happens

`build-app` assembles a VFS tree: the app under `app/` (including its bundled
`icon.png`), the module trees under `lib/tm/`, the included packages under
`pkgs/`, `tcl_library`/`tk_library` copied from the basekit, a bootstrap shim
`_lib/paths.tcl`, and a generated `main.tcl` that loads Tk, sources the app,
runs `-launch`, and holds the event loop open. Then `zipfs mkimg` appends the
tree to the basekit. Details in `build-app-guide.md`.
