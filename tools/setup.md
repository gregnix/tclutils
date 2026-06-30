# setup.tcl — making the tclutils / tkutils libraries discoverable

`setup.tcl` is a small bootstrap that tells Tcl where the `tclutils` and
`tkutils` module libraries live. After sourcing it, `package require` works in
your own application without any further path setup:

```tcl
source /path/to/tkutils/tools/setup.tcl     ;# or .../tclutils/tools/setup.tcl
package require tclutils::tubin
package require tkutils::tkucsv
```

The file is **identical in both packages**, and sourcing either one makes
**both** libraries discoverable — `tkutils` depends on `tclutils`. It is the
**single source of truth** for path resolution: the bundled apps under `apps/`
do not duplicate the logic, they reach it through the thin wrapper
`apps/_lib/paths.tcl`, which just sources this file.

## Why it is needed

`tclutils` and `tkutils` ship as Tcl modules (`tcl::tm`) under `lib/tm/<pkg>/`.
Tcl only finds a module when the matching `lib/tm` directory is on the module
search path (`tcl::tm::path list`). A freshly unpacked library is not among the
default locations, so without this step you get `can't find package …` at
startup.

## What it resolves

For each package the resolver tries the locations below in priority order and
adds only the ones that **exist** (the override ends up at the head of the
module path):

1. `TCLUTILS_TM` / `TKUTILS_TM` — explicit override (wins)
2. `<this-repo>/lib/tm` — the package this file ships in
3. `[file dirname [info library]]/<pkg>/lib/tm` — next to the Tcl install (Linux **and** Windows)
4. `/usr/local/share/tcltk/<pkg>/lib/tm` — system-wide (Unix)
5. `$XDG_DATA_HOME` / `~/.local/share/tcltk/<pkg>/lib/tm` — per user (XDG)
6. `<holder>/<pkg>/lib/tm` — side-by-side checkout, unversioned folder
7. `<holder>/<pkg>-*/lib/tm` — side-by-side, **versioned** folder (highest version)

`<holder>` is a directory that may contain the sibling library folders. Two
placements are handled automatically:

**a) inside the package** (as shipped):

```
~/lib/tcltk/
├── tclutils-0.58.0/
│   ├── tools/setup.tcl     ← source this
│   └── lib/tm/tclutils/…
└── tkutils-0.41.0/
    └── lib/tm/tkutils/…
```

**b) loose**, dropped directly next to the library folders:

```
~/lib/tcltk/
├── setup.tcl               ← source this
├── tclutils-0.58.0/lib/tm/…
└── tkutils-0.41.0/lib/tm/…
```

Both versioned (`tclutils-0.58.0/`) and unversioned (`tclutils/`) folder names
are accepted; for versioned siblings the highest version is chosen. Because the
`.tm` files themselves are already version-stamped (`tubin-0.1.tm`), Tcl then
picks the highest matching version automatically.

A genuinely missing package surfaces **loudly** via `package require` — that is
the intended signal, not this resolver.
