# tclutils::tuappinfo

Collect application / system information into a plain-text report: Tcl/Tk
versions, executable, platform, selected environment variables, search paths,
loaded packages, and an optional list of explicitly tracked module files.
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
  masks user/host names (stable hash), `HOME`/`TEMP` paths, and `PATH`.
- `writeLog` — write `buildReport` to `file`; returns the file path.

```tcl
puts [::tclutils::tuappinfo::buildReport -title "MyApp 1.0"]
::tclutils::tuappinfo::writeLog /tmp/myapp-info.txt -title "MyApp 1.0" -anonymize 1
```

## Demo

```bash
tclsh examples/demo-tuappinfo.tcl
```
