# tupath

Predictable path helpers around Tcl's `file` command, plus a purely lexical
`clean` (works on non-existent paths) and `commonPath`.

## Commands

| Command | Result |
|---------|--------|
| `normalize path` | absolute path, resolves `.`/`..` and symlinks (`file normalize`) |
| `clean path` | lexical cleanup of `.`/`..`/`//` **without** touching the filesystem |
| `isAbsolute path` | 1/0 |
| `components path` | list of path parts (`file split`) |
| `join args...` | join parts (`file join`) |
| `relative base target` | lexical path of `target` relative to `base` |
| `commonPath {paths}` | longest shared directory prefix, or `""` if none |
| `readlink path` | symlink target (`{TCLUTILS TUPATH NOTLINK}` if not a link) |

```tcl
package require tclutils::tupath
tupath::clean      a/./b/../c           ;# a/c
tupath::commonPath {/a/b/c /a/b/d}      ;# /a/b
tupath::relative   /a/b /a/b/c/d        ;# c/d
```

`clean` and `relative` are purely lexical, so they are safe for paths that do
not exist; `normalize` and `readlink` consult the filesystem.
