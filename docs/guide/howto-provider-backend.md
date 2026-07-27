# HOWTO: write a provider backend

A backend teaches `tuprovider` how to reach one kind of storage. Once written,
every consumer that speaks the provider interface -- a tree walker, a file list,
a copy routine -- works over your storage with no further changes.

## The recipe

1. Subclass `::tclutils::tuprovider::Base`.
2. Override only the operations your storage can do.
3. Register the class under a scheme name.

```tcl
package require tclutils::tuprovider

oo::class create ::tclutils::tuprovider::Mem {
    superclass ::tclutils::tuprovider::Base
    variable Files                          ;# path -> content

    constructor {} { set Files [dict create] }

    # seed some data (not part of the interface, just for the example)
    method seed {path content} { dict set Files $path $content }

    method list {dir} {
        set out {}
        dict for {p c} $Files {
            if {[file dirname $p] eq $dir} {
                lappend out [dict create name [file tail $p] path $p \
                                 type file size [string length $c]]
            }
        }
        return $out
    }
    method stat {path} {
        if {![dict exists $Files $path]} { error "no such path: $path" }
        return [dict create name [file tail $path] path $path type file \
                    size [string length [dict get $Files $path]]]
    }
    method get {path} {
        if {![dict exists $Files $path]} { error "no such path: $path" }
        return [dict get $Files $path]
    }
}

::tclutils::tuprovider::register mem ::tclutils::tuprovider::Mem
```

## Use it

```tcl
set p [::tclutils::tuprovider open mem]
$p seed /notes/a.txt "first"
$p seed /notes/b.txt "second"

puts [$p caps]                ;# => list stat get
foreach e [$p list /notes] { puts [dict get $e name] }
puts [$p get /notes/a.txt]    ;# => first
```

## Why you only override what you support

`caps` is not a list you maintain by hand. It is computed by introspection: an
operation counts as supported when a class **other than `Base`** implements it.
Because `Mem` overrides only `list`, `stat` and `get`, those three -- and only
those -- appear in `caps`. The writing operations still resolve to `Base`'s
default, which raises "not supported", so a UI driven by `caps` never offers
them.

To make a writable backend, override `put`, `delete`, `mkdir`, `move` and/or
`copy` as well; each one you add shows up in `caps` automatically.

## Contract notes

- **Paths are opaque.** A consumer feeds back exactly the `path` you put in an
  entry dict; you decide what a path means for your storage.
- **`get` returns raw bytes.** Do not apply an encoding; a text consumer decodes
  what it reads.
- **Entry dicts** carry at least `name`, `path`, `type` (`file`/`dir`) and
  `size`; add `mtime` where you can.
- **`copy`/`move` are provider-internal.** Copying *between* providers is done
  by the application with `get`+`put` -- see
  [howto-cross-provider-copy.md](howto-cross-provider-copy.md).

## See also

- Module reference: [`../tuprovider.md`](../tuprovider.md)
- [howto-browse-zip.md](howto-browse-zip.md)
- [howto-cross-provider-copy.md](howto-cross-provider-copy.md)
