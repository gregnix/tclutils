# tusize

A small `du`: recursive byte totals and human-readable formatting. Symlinks are
not followed: a link counts with its own size (`file lstat`, on Unix the
length of the target path), so cyclic links cannot loop.

## Commands

| Command | Result |
|---------|--------|
| `bytes path` | size of a file, or recursive total of a directory (incl. dotfiles) |
| `human n ?-si 0\|1?` | human-readable size; binary units (KiB ... YiB) by default, decimal (kB ... YB) with `-si 1` |
| `entries dir` | list of `{bytes path}` for each immediate child, sorted by path |

```tcl
package require tclutils::tusize
tusize::bytes   ./project          ;# 1048576
tusize::human   1536               ;# 1.5 KiB
tusize::human   1500 -si 1         ;# 1.5 kB
tusize::entries ./project          ;# {4096 ./project/docs} {2048 ./project/src} ...
```

The unit always names its base: `KiB` is 1024, `kB` is 1000. 1500 and 1536
bytes are both `1.5 KiB` because one decimal is shown; `tunumfmt::toHuman`
writes the bare `K` for 1000 (`1.5K`), like `numfmt`.

Errors use `{TCLUTILS TUSIZE ...}` (`NOTFOUND`, `NOTDIR`, `VALUE`).
