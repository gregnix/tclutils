# Building on Windows (no Linux)

The whole toolchain runs the same on Windows — for anyone with no Linux, or with
Windows as their main system. Only the basekits (`.exe` files) and the path /
quoting syntax change. No installed Tcl, no installed tclutils on the target.

All calls work in `cmd.exe` and in PowerShell. Tcl also accepts **forward
slashes** in paths on Windows — that is the simplest; backslashes work too.

## Prerequisites

Static Windows basekits (from BAWT or magicsplat):

- `zipkit-9_0_4-win64-intel-tcl.exe` — console interpreter, for **CLI** apps.
- `zipkit-9_0_4-win64-intel-tk.exe` — GUI interpreter **without** a console
  window, for **GUI** apps.

For the "bootstrap the builder yourself" path you also need the `tclutils` tree.

## The easy way: a ready-made build-app.exe

If a ready `build-app.exe` is available (shipped, or bootstrapped once, see
below), the build host needs **only** that file and the basekits.

A CLI app to an exe (console basekit):

```bat
build-app.exe -kind cli -out find-tclconfig.exe ^
    -basekit zipkit-9_0_4-win64-intel-tcl.exe ^
    -app find-tclconfig -main find-tclconfig.tcl
```
```
built: find-tclconfig.exe (3873710 bytes)
```

A GUI app to an exe (GUI basekit, `-launch`, module trees). In `cmd`/PowerShell,
use **double** quotes:

```bat
build-app.exe -kind gui -out notes-app.exe ^
    -basekit zipkit-9_0_4-win64-intel-tk.exe ^
    -app ../tkutils/apps/notes-app -main notes_app.tcl ^
    -launch "::notesapp::buildApp ." ^
    -tm lib/tm -tm ../tkutils/lib/tm ^
    -extlib C:/Tcl/lib
```
```
built: notes-app.exe (7299242 bytes)
```

The `^` at end of line is `cmd.exe` line continuation (PowerShell: backtick
`` ` ``; one line always works). Then start by double-click or from the terminal:
`find-tclconfig.exe`, `notes-app.exe`.

## Bootstrap build-app.exe yourself (once)

Only needed when no ready `build-app.exe` exists or `tuzipfs` was updated. The
console basekit runs the raw script, which packages itself:

```bat
zipkit-9_0_4-win64-intel-tcl.exe apps/build-app/build-app.tcl ^
    -kind cli -out build-app.exe ^
    -basekit zipkit-9_0_4-win64-intel-tcl.exe ^
    -app apps/build-app -main build-app.tcl ^
    -tm lib/tm
```
```
built: build-app.exe (4199323 bytes)
```

Afterwards `build-app.exe` is self-contained (no tclutils needed any more).

## Windows specifics

- **No Xvfb.** When building a GUI exe the prober starts the app briefly — on
  Windows the normal desktop is available, nothing else to do. Only on a
  **headless** Windows server (no desktop) do you build GUI apps with `-probe 0`
  and give the module trees via `-tm` yourself.
- **Console vs GUI.** The `...-tcl.exe` basekit opens a console window (good for
  CLI tools); the `...-tk.exe` basekit has none (so GUI apps show no stray black
  window).
- **Quoting.** Put values with spaces such as `-launch "::notesapp::buildApp ."`
  in double quotes (cmd and PowerShell).
- **Running.** Double-click or from `cmd`/PowerShell. Distributing = copy the one
  file; it runs on any Windows x64 without installation.

## The other way round: Linux binaries from Windows

The Windows host can just as well build **Linux** binaries — pass a Linux basekit
as `-basekit`. Since cross-platform probing is not possible, build with
`-probe 0` (dependencies known from a run on the target platform):

```bat
build-app.exe -kind gui -out notes-app -probe 0 ^
    -basekit zipkit-9_0.4-Linux64-intel-tk ^
    -app ../tkutils/apps/notes-app -main notes_app.tcl ^
    -launch "::notesapp::buildApp ." ^
    -tm lib/tm -tm ../tkutils/lib/tm
```

## Note on verification

The Windows binaries shown here (`build-app.exe`, `find-tclconfig.exe`,
`notes-app.exe`) were cross-built on Linux and verified as valid Windows zipkits
(PE header `MZ`, appended ZIP with `main.tcl`/stdlib/modules); the sizes shown
are the actual ones. The `built: …` messages are the tool's platform-independent
output — on Windows they appear identically.
