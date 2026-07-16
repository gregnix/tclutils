# tclutils — apps

Standalone command-line programs. Each app has its own folder (source, tests,
optionally examples). Unlike the tkutils apps, these are Tk-free.

| App | Purpose |
|---|---|
| `find-tclconfig/` | locate `tclConfig.sh` / `tkConfig.sh` and emit correct `--with-tcl`/`--with-tk` pairs (never across trees) |
| `build-app/` | turn a tclutils/tkutils app into a standalone Tcl 9 zipkit (single executable) via `tclutils::tuzipfs` |

Prebuilt binaries live in `bin/` — e.g. `bin/build-app-zipkit-linux`, the
`build-app` builder packaged as a self-contained zipkit so a build host needs
only that file plus the BAWT/magicsplat basekits.

## Dependencies

Apps here state their own requirements. `find-tclconfig/` is deliberately
dependency-free — it needs only a `tclsh` (8.6 or 9.0) and no tclutils modules,
because it is meant to run on a bare system before anything is set up. Apps that
*do* use tclutils modules should resolve the module path themselves (env override
plus repo-relative search), as the tkutils apps do via `_lib/paths.tcl`.

`build-app/` needs `tclutils::tuzipfs` (0.2+): the raw `build-app.tcl` finds it
repo-relative or via `-tm`, and the packaged `bin/build-app-zipkit-linux`
carries it embedded. See `build-app/README.md` and `docs/guide/build-app.md`.
