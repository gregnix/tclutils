# tclutils::tustat

` tustat ` provides stat-like file metadata helpers around Tcl's `file stat`.

## API

```tcl
package require tclutils::tustat
set d [::tclutils::tustat::file README.md]
puts [dict get $d size]
puts [::tclutils::tustat::render $d]
```

Commands:

- `file path` returns metadata as a dict.
- `files paths` returns one metadata dict per path.
- `format statDict ?-timeformat fmt?` formats selected fields.
