# tclutils::tuappinfo

Collect application / system information into a plain-text report: Tcl/Tk
versions and libraries, executable, platform, selected environment variables,
the variables that steer the package search, search paths, loaded packages
with their origin, loaded shared libraries, and an optional list of
explicitly tracked module files.
Supports anonymisation of user / host / path data. Pure Tcl, no GUI -- the
caller renders the returned text (e.g. in a Tk window or a log file).

## API

```tcl
::tclutils::tuappinfo::trackTm    file
::tclutils::tuappinfo::buildReport ?-title str? ?-anonymize 0|1?
::tclutils::tuappinfo::writeLog    file ?-title str? ?-anonymize 0|1?
```

- `trackTm` — record a module file path so it appears under "Loaded TM
  Modules" (otherwise that section reads "(none tracked)").
- `buildReport` — return the full report as a single string. `-anonymize 1`
  masks user/host names (stable hash), `TEMP`/`TMP` (`<TEMP>`), `PATH`
  (`<anonymized>`), tracked module files (`<tm-HASH>.tm`) and every path in
  the report (`Executable`, the libraries, `HOME`, the search variables,
  `auto_path`, `tcl_pkgPath`, package origins, loaded libraries,
  `tm::path`) by one rule:
  a path equal to or below the home directory (`$HOME`, else
  `$USERPROFILE`) becomes `<HOME>/rest` (`HOME` itself `<HOME>`), any other
  path becomes `<path>/<last component>`, e.g. `/usr/share/tcltk` ->
  `<path>/tcltk`. Separators are shown as `/`; on Windows the home prefix is
  compared without case.
- Options: unknown options and an option without a value raise
  `{TCLUTILS TUAPPINFO OPTION}`, a non-boolean `-anonymize` raises
  `{TCLUTILS TUAPPINFO VALUE}`.
- `writeLog` — write `buildReport` to `file` as UTF-8 through a temporary
  file (`common::replaceFile`), so a failed write keeps an old log; returns
  the file path (0.3; up to 0.2 in the system encoding).
- The Tk line shows the patch level (`9.0.4`), as the Tcl line does (0.3;
  up to 0.2 `tk_version`, `9.0`).

Sections, in this order ("0.3": new in 0.3):

| Section | Content |
|---|---|
| head | title, `Timestamp:`, `PID:` |
| `--- Tcl / Tk ---` | Tcl version, `Tcl library:` (0.3); with Tk the patch level, `Tk library:` and `Windowing system:` (0.3); executable, platform, machine, `Host:` from `info hostname` (0.3: on every platform; `COMPUTERNAME` only as fallback) |
| `--- Environment ---` | `USER`, `USERNAME`, `HOME`, `TEMP`, `TMP`, `PATH`, if set |
| `--- Search variables ---` | 0.3: `TCLLIBPATH`, every `TCL<x>_<y>_TM_PATH`, `LD_LIBRARY_PATH`, `DYLD_LIBRARY_PATH`, if set; one entry per line; otherwise `(none set)` |
| `--- auto_path ---` | one entry per line |
| `--- tcl_pkgPath ---` | 0.3, only where the variable exists (not on Windows) |
| `--- Loaded Packages ---` | name, version and (0.3) the file that `package ifneeded` sources or loads; empty for built-in packages and for scripts without a literal file name |
| `--- Loaded Libraries ---` | 0.3: `info loaded`, prefix and file; `(static)` for a statically linked package |
| `--- tm::path ---` | `tcl::tm::path list`, in search order |
| `--- Loaded TM Modules ---` | files recorded with `trackTm`, else `(none tracked)` |

A folder in the search variables, `auto_path`, `tcl_pkgPath` and `tm::path`
that does not exist ends in ` (missing)` (0.3). `Loaded Libraries` is the
proof of which shared library was loaded: two packages of the same name in
different folders are told apart there.

```tcl
puts [::tclutils::tuappinfo::buildReport -title "MyApp 1.0"]
::tclutils::tuappinfo::writeLog /tmp/myapp-info.txt -title "MyApp 1.0" -anonymize 1
```

## Demo

```bash
tclsh examples/demo-tuappinfo.tcl
tclsh examples/demo-tuappinfo.tcl sqlite3      ;# load first, then report
tclsh examples/demo-tuappinfo.tcl -anonymize sqlite3
```
