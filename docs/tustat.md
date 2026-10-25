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
- `render statDict ?-timeformat fmt?` formats selected fields
  (`path type size mtime mode ino dev uid gid`).

The dict holds the keys of `file stat` (`atime blksize blocks ctime dev
gid ino mode mtime nlink size uid`) plus `modeOctal` (mode in octal, e.g.
`100644`), `path`, `normalized` and `type`. `mode` itself is decimal.

Symbolic links are not followed, like `stat` without `-L`: for a link the
values come from `file lstat` (the link itself), and the extra key
`target` holds `file readlink`. A dangling link is therefore no error.
A missing path raises `{POSIX ENOENT ...}`.
