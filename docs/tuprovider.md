# tclutils::tuprovider

A storage-provider interface: one small abstraction over every storage back end
(local filesystem, ZIP, WebDAV, ...). For a consumer -- a directory tree, a file
list -- everything is just a path with children; where the bytes actually live
does not matter.

## Load

```tcl
tcl::tm::path add /path/to/tclutils/lib/tm
package require tclutils::tuprovider
```

The `local` backend is built in. Other schemes register themselves when their
package is loaded (`tuprovider::zip`, `tuprovider::dav`).

## Open a provider

```tcl
set p [::tclutils::tuprovider open local]
set p [::tclutils::tuprovider open zip /path/archive.zip]
set p [::tclutils::tuprovider open dav https://host/dav/]
```

`open $scheme ?args?` returns a provider object; extra args go to the backend.
An unknown scheme is an error.

## The interface

A provider answers these operations. Each takes provider paths (opaque to the
consumer) and returns entry dicts or bytes:

| Operation | Signature | Result |
|-----------|-----------|--------|
| `list`   | `list $path`        | list of entry dicts, one level, on demand |
| `stat`   | `stat $path`        | one entry dict, or error if absent |
| `get`    | `get $path`         | file contents as **raw bytes** |
| `put`    | `put $path $data`   | write contents |
| `delete` | `delete $path`      | remove |
| `mkdir`  | `mkdir $path`       | create a directory/collection |
| `move`   | `move $from $to`    | rename/move within the provider |
| `copy`   | `copy $from $to`    | copy within the provider |
| `caps`   | `caps`              | which of the above are supported |

`get` returns **raw bytes** (no encoding applied); a text consumer decodes them
itself. Copying *across* providers is done at the application level with
`get`+`put`, not with `copy` (which is provider-internal only).

## Entry dicts

`list` and `stat` return dicts with at least:

```
name   the leaf name
path   the provider path (feed back into list/stat/get)
type   file | dir
size   byte size (files)
mtime  modification time (where the backend provides it)
```

## Capabilities

Not every backend can do everything -- a ZIP is read-only, WebDAV has no
copy/move. `caps` reports the truth so a UI never offers an operation that would
fail:

```tcl
if {"put" in [$p caps]} { $p put $dest $bytes }
```

Capabilities are discovered by introspection: a method counts as supported when
a class other than the `Base` class implements it. A backend therefore just
inherits `Base` and overrides the operations it can do -- its `caps` follow
automatically, at any inheritance depth.

## Public commands

- `::tclutils::tuprovider::open $scheme ?args?` -- create a provider.
- `::tclutils::tuprovider::register $scheme $class` -- register a backend class
  under a scheme (backends call this on load).
- `::tclutils::tuprovider::schemes` -- list the registered schemes.

A provider also offers `head $path $len` -- return at most `$len` bytes from the
start of a file (`$len <= 0` means the whole file). The base class implements it
via `get` + truncate; the local provider overrides it to read only the prefix,
so a UI can preview a large binary without loading it entirely.

## Writing a backend

Subclass `::tclutils::tuprovider::Base`, override the operations you support,
and register the class:

```tcl
oo::class create ::tclutils::tuprovider::MyBack {
    superclass ::tclutils::tuprovider::Base
    method list {path} { ... }
    method stat {path} { ... }
    method get  {path} { ... }
}
::tclutils::tuprovider::register myscheme ::tclutils::tuprovider::MyBack
```

Only the overridden operations appear in `caps`; the rest inherit `Base`'s
"not supported" default.

## See also

`tuprovider::zip`, `tuprovider::dav`
