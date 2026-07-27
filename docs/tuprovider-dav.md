# tclutils::tuprovider::dav

A WebDAV backend for the `tuprovider` interface, built on `tudav`.

It lets the same tree and list consumers that work over the local filesystem
work over a WebDAV server without change: for the consumer, a DAV path is just a
path with children.

## Load

```tcl
tcl::tm::path add /path/to/tclutils/lib/tm
package require tclutils::tuprovider::dav
```

Loading the package registers the `dav` scheme with `tuprovider`.

## Open

```tcl
set p [::tclutils::tuprovider open dav https://host/remote.php/dav/files/me/]
```

Extra arguments after the URL are passed through to `tudav::client` (for
credentials and options).

## Capabilities

`dav` reports:

```
list stat get put delete
```

It deliberately does **not** report `mkdir`, `move` or `copy`: `tudav` has no
public MKCOL/MOVE/COPY, so the provider reports honestly what it can do. A UI
driven by `caps` will not offer operations that would fail.

## Operations

- `list $path` -- returns entry dicts for the collections and resources under
  `$path`. Collections become `type dir`, resources `type file`. The entry
  `name` is derived from the href tail (`/a/b/` -> `b`, `/a/f.txt` -> `f.txt`).
- `stat $path` -- a cheap existence/type check via a depth-0 request.
- `get $path` -- fetches the resource bytes.
- `put $path $bytes`, `delete $path` -- the writing half.

## Notes and limits

- Paths are DAV hrefs, relative to the client URL; the consumer treats them as
  opaque paths.
- `stat` derives dir/file heuristically from a trailing slash, because
  `tudav`'s property lookup does not report the type reliably across servers.
- `name` derivation keeps percent-decoding minimal; hrefs are usually clean.
- The HTTP traffic itself is `tudav`'s concern. What this adapter adds is the
  href -> entry mapping and the honest `caps` subset.

## See also

`tuprovider`, `tuprovider::zip`, `tudav`
