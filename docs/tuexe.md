# tclutils::tuexe

Locate external executables across bundled directories and the system PATH,
trying a list of candidate names and platform-specific extensions. Generalises
the common "find `gs` / `gswin64c` / ... via `auto_execok`" idiom and adds
support for bundled (vendor) binary directories. Pure Tcl.

## API

```tcl
::tclutils::tuexe::find   names ?-dirs {d ...}? ?-pathfirst 0|1? ?-all 0|1?
::tclutils::tuexe::all    names ?-dirs {d ...}? ?-pathfirst 0|1?
::tclutils::tuexe::exists names ?-dirs {d ...}? ?-pathfirst 0|1?
```

`names` is a single name or a list of candidates (tried in order). `find`
returns the first resolved, normalized path (or `""`); `all` returns every
match, de-duplicated, in search order; `exists` returns 0/1.

- `-dirs` lists extra directories to search (e.g. bundled vendor `bin` dirs).
- `-pathfirst 0` (default) searches `-dirs` before PATH, so a shipped binary
  wins deterministically; `-pathfirst 1` prefers the system PATH.
- On Windows, names are tried with `PATHEXT` extensions (or `.exe .com .bat
  .cmd`); on Unix a file must be executable to match.

```tcl
set gs   [tuexe::find {gs gswin64c gswin32c gsc}]        ;# system Ghostscript
set qpdf [tuexe::find qpdf -dirs [list $appVendorBin]]   ;# bundled, else PATH
if {[tuexe::exists ffmpeg]} { ... }
```

## Errors

Unknown options carry `{TCLUTILS TUEXE OPTION}`.

## Demo

```bash
tclsh examples/demo-tuexe.tcl
```
