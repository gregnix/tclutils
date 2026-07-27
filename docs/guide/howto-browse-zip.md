# HOWTO: browse a ZIP archive as a tree

The `zip` backend lets you walk a ZIP archive the same way you walk a directory
tree: `list` a path to see its children, recurse into the ones of type `dir`,
`get` a file to read its bytes. You never touch the archive format directly.

## Open the archive

```tcl
package require tclutils::tuprovider
package require tclutils::tuprovider::zip     ;# registers the "zip" scheme

set p [::tclutils::tuprovider open zip /path/to/archive.zip]
```

## Walk the whole tree

`list` returns one level at a time, on demand. Recurse into directories:

```tcl
proc walk {p dir {indent ""}} {
    foreach e [$p list $dir] {
        puts "$indent[dict get $e name][expr {[dict get $e type] eq "dir" ? "/" : ""}]"
        if {[dict get $e type] eq "dir"} {
            walk $p [dict get $e path] "  $indent"
        }
    }
}
walk $p /
```

For an archive containing `top.txt`, `sub/inner.txt` and `sub/deep/x.txt` this
prints:

```
top.txt
sub/
  inner.txt
  deep/
    x.txt
```

## Read a file

```tcl
set bytes [$p get /sub/deep/x.txt]
```

`get` returns **raw bytes**. For text, decode them yourself:

```tcl
set text [encoding convertfrom utf-8 $bytes]
```

## Synthesized directories

A ZIP stores a flat list of member names; the intermediate directories are not
always stored as their own entries. The provider **synthesizes** them: given a
member `sub/deep/x.txt`, it presents `sub` and `sub/deep` as directories even
when no explicit entry exists. That is what lets a plain tree walker (or a tree
widget) traverse an archive as if it were a filesystem -- you do not have to
special-case missing directory entries.

## Read-only

The `zip` backend reports `caps` = `list stat get`. Any writing operation is
refused:

```tcl
$p put /new.txt data     ;# error: provider ... does not support 'put'
```

To copy a file *out* of the archive into writable storage, read it with `get`
and write it with the target provider's `put` -- see
[howto-cross-provider-copy.md](howto-cross-provider-copy.md).

## See also

- Module reference: [`../tuprovider-zip.md`](../tuprovider-zip.md)
- [howto-provider-backend.md](howto-provider-backend.md)
- [howto-cross-provider-copy.md](howto-cross-provider-copy.md)
