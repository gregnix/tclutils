# tclutils::tuprovider::zip

A read-only ZIP backend for the `tuprovider` interface, built on `tuzip`.

It lets the same tree and list consumers that work over the local filesystem
browse the contents of a ZIP archive without change: for the consumer, an entry
in the archive is just a path with children.

## Load

```tcl
tcl::tm::path add /path/to/tclutils/lib/tm
package require tclutils::tuprovider::zip
```

Loading the package registers the `zip` scheme with `tuprovider`.

## Open

```tcl
set p [::tclutils::tuprovider open zip /path/to/archive.zip]
```

## Capabilities

`zip` reports the read-only subset:

```
list stat get
```

Writing operations (`put`, `delete`, `mkdir`, `move`, `copy`) are not reported,
so a UI driven by `caps` will not offer them. To copy a file *out* of an
archive, read it with `get` and write it into a writable provider with `put`
(this is what a cross-provider copy does at the application level).

## Operations

- `list $path` -- returns entry dicts for the children of `$path`.
- `stat $path` -- returns the entry dict for a single path.
- `get $path` -- returns the raw bytes of an archived file.

## Directory synthesis

A ZIP archive stores a flat list of member names; intermediate directories are
not always present as their own entries. This provider **synthesizes** the
directory tree from the member paths: given `sub/deep/x.txt`, it presents `sub`
and `sub/deep` as directories even when no explicit entry for them exists. This
is what lets a plain tree widget walk an archive as if it were a filesystem.

## Notes and limits

- Read-only by design: an archive is treated as an immutable source.
- The archive is opened once when the provider is created; `tuzip` handles the
  actual reading.

## See also

`tuprovider`, `tuprovider::dav`, `tuzip`
