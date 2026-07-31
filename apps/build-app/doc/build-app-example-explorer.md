# Step by step: explorer (GUI) as a standalone program

This example builds the file-manager app `explorer` (from the ctrlutils repo)
into a single self-contained program with `build-app`. The explorer is the
biggest example so far: it pulls in **three** module trees (tclutils, tkutils
and ctrlutils) plus **two** external packages (Tablelist and Scrollutil from
tklib), and it has several *optional* backends (image formats, SVG, PDF, SQLite)
that it degrades gracefully without.

If you have not seen a simpler build first, read `build-app-example-notes-app.md`.

## What the explorer needs

Its `package require`s span all three repos:

- tclutils: `tuprovider` (+ the sub-providers dav/ftp/sftp/zip, loaded on demand),
  `tuopen`
- tkutils: `tkufiletree`, `tkufilelist`, `tkupath`, `tkutab`, `tkupreview`, and
  the dialog/menu/hex helpers those pull in
- ctrlutils: `cufileops`, `cufilter`, `cumonitor`, `cuundo`
- external (tklib): **Tablelist** (the multi-column list) and **Scrollutil**
  (Tablelist's scroll helper)

Optional, detected at runtime and skipped if absent: `img::*` (extra image
formats), `tcllunasvg` (SVG), `pdfiumtcl`/`tclpdfium` (PDF), `sqlite3`.

## The build command (Linux)

```
cd tclutils/apps/build-app

xvfb-run -a ./build-app-zipkit-linux -kind gui -out explorer \
    -basekit <wish-basekit> \
    -app ../../../ctrlutils/apps/explorer -main explorer.tcl \
    -launch '::explorer::main $argv' \
    -tm ../../lib/tm \
    -tm ../../../tkutils/lib/tm \
    -tm ../../../ctrlutils/lib/tm \
    -include <tklib>/modules/tablelist=pkgs/tablelist \
    -include <tklib>/modules/scrollutil=pkgs/scrollutil \
    -probe 0
```

The important options:

- `-kind gui` -- a GUI app, so a **wish** basekit and an event loop.
- `-launch '::explorer::main {}'` -- the call that opens the window. It is needed
  because the explorer's `main` only auto-runs when the script is the program's
  argv0, and that "am I the main script?" check does not fire inside a zipkit.
  `$argv` forwards the program's arguments, so `explorer <dir>` opens that
  directory; with none it starts in the current directory.
- **Three `-tm` trees** -- tclutils, tkutils AND ctrlutils. Miss one and the app
  fails at `package require` for a module in that repo.
- **Two `-include`** -- Tablelist and Scrollutil are ordinary (non-tm) packages,
  so they are copied under `lib/pkgs` and the app finds them because build-app
  puts `//zipfs:/app/lib/pkgs` on `auto_path`.
- `-probe 0` -- the explorer loads optional backends conditionally; the prober
  would try to start the app to trace its dependency closure, which is
  unnecessary here (all the *required* packages are in the `-tm` trees and the
  two includes). Leaving the prober on is harmless but slower.

Double-quote `-launch` -- curly braces do not quote in the shell.

## Basekit note (portability)

Use a **statically linked** basekit (e.g. `runtimes/zipkit-9_0.4-Linux64-intel-tk`)
if you want a single file that runs on machines without a Tcl/Tk install. A
dynamically linked wish (one whose `ldd` shows `libtcl9*.so`) produces a program
that still needs those shared libraries present on the target -- fine for your
own machine, not for shipping. Check with:

```
ldd explorer | grep -iE 'tcl|tk9' || echo "no libtcl/libtk dep (portable)"
```

## Windows cross-build

Same shape, but with the Windows basekit and the prober off (a Linux host cannot
start a Windows .exe to trace it):

```
wish9.0 build-app.tcl -kind gui -out explorer.exe \
    -basekit ../../../runtimes/zipkit-9_0_4-win64-intel-tk.exe \
    -app ../../../ctrlutils/apps/explorer -main explorer.tcl \
    -launch '::explorer::main $argv' \
    -tm ../../lib/tm -tm ../../../tkutils/lib/tm -tm ../../../ctrlutils/lib/tm \
    -include <tklib>/modules/tablelist=pkgs/tablelist \
    -include <tklib>/modules/scrollutil=pkgs/scrollutil \
    -probe 0
```

No `-stdlibfrom` is needed: it defaults to `basekit`, so the Tcl/Tk standard
library is taken from the Windows zipkit basekit -- which is exactly the target's
stdlib. (`-launch '::explorer::main $argv'` lets `explorer.exe C:\some\dir` open
that directory; with no argument it starts in the current directory.) To give the
.exe its own file icon, set it afterwards with `rcedit` (see `windows-icon.md`).

## Verifying the result

```
# smoke: does it build the window and load every module?
SMOKE=1 xvfb-run -a ./explorer            # if the app honours a SMOKE env guard
xvfb-run -a ./explorer /some/dir          # or just start it on a directory

# confirm the modules and providers are bundled:
tclsh9.0 <<'TCL'
zipfs mount ./explorer app
puts [glob -tails -directory //zipfs:/app/lib/tm *]
puts [glob -tails -directory //zipfs:/app/lib/tm/tclutils/tuprovider *]
TCL
```

You should see the three module trees under `lib/tm`, the four sub-providers
(dav, ftp, sftp, zip) under `tclutils/tuprovider`, and `tablelist` + `scrollutil`
under `pkgs`.

## Optional backends

The built program works with only the required packages. To enable a backend,
bundle it too:

- **SVG preview**: `-include <path>/tcllunasvg=pkgs/tcllunasvg`
- **Extra image formats** (JPEG/TIFF/...): include the Img package the same way.
- **PDF preview**: include `pdfiumtcl`/`tclpdfium` and its shared library.
- **SQLite preview**: include `sqlite3`.

Each is optional -- without it the explorer simply shows a "renderer not
available" note for that file type and everything else keeps working.
