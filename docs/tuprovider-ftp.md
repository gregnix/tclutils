# tclutils::tuprovider::ftp

An FTP backend for the `tuprovider` interface, built on the tcllib `ftp` client.

It lets the same tree and list consumers that work over the local filesystem work
over a remote FTP server without change: for the consumer, an FTP path is just a
path with children.

## Load

```tcl
tcl::tm::path add /path/to/tclutils/lib/tm
package require tclutils::tuprovider::ftp
```

Loading the package registers the `ftp` scheme with `tuprovider`.

## Open

```tcl
set p [::tclutils::tuprovider open ftp ftp://host/pub -user me -password secret]
```

The URL is `ftp://host[:port][/base]`. Options after it go to `ftp::Open`:
`-user`, `-password`, `-port`, `-mode passive|active`, `-timeout`. Anonymous is
the default. A `/base` in the URL is entered with `CD` after connecting.

## Capabilities

`ftp` reports the full read/write set FTP supports:

```
list stat get put delete mkdir move
```

It does **not** report `copy`: FTP has no server-side copy. To copy a file, read
it with `get` and write it back with `put` (a cross-provider copy does exactly
this at the application level). `move` maps to the FTP `RENAME` command.

## Operations

- `list $path` -- parses the server's `LIST` output into entry dicts. The common
  Unix listing format is assumed (`perms links owner group size date name`); the
  leading char of the perms column marks a directory. Names with spaces are kept
  whole.
- `stat $path` -- derives dir/file by trying to `CD` into the path (dir if it
  succeeds), with `FileSize` for files.
- `get` / `put` / `delete` / `mkdir` / `move` -- forward to the matching ftp
  commands.

## Notes and limits

- **LIST is not standardized.** This adapter parses the common Unix format; a
  server emitting a different format (some Windows FTP servers) may not parse
  cleanly. `NLST`-only servers are not handled.
- Paths are absolute FTP paths; the consumer treats them as opaque.
- The FTP traffic itself is tcllib's concern. What this adapter adds is the LIST
  parsing, the path -> entry mapping, and the honest `caps` set.

## See also

`tuprovider`, `tuprovider::dav`, `tuprovider::zip`
