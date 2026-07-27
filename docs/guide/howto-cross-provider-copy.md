# HOWTO: copy a file across providers

`copy` and `move` on a provider work *within* that provider only. To move data
**between** providers -- pull a file out of a ZIP into a local directory, push a
local file to WebDAV -- you read from the source and write to the target. Both
speak the same interface, so the source being a ZIP and the target a filesystem
makes no difference to your code.

## One file

```tcl
package require tclutils::tuprovider
package require tclutils::tuprovider::zip

set src [::tclutils::tuprovider open zip /path/archive.zip]
set dst [::tclutils::tuprovider open local]

set bytes [$src get /docs/readme.txt]        ;# read from the ZIP
$dst put /home/me/readme.txt $bytes          ;# write to local disk
```

That is the whole idea: `get` from one, `put` to the other.

## A whole directory (recursive)

Recurse with `list`, creating directories on the target and copying files:

```tcl
proc copyTree {src from dst to} {
    $dst mkdir $to
    foreach e [$src list $from] {
        set child [file join $to [dict get $e name]]
        if {[dict get $e type] eq "dir"} {
            copyTree $src [dict get $e path] $dst $child
        } else {
            $dst put $child [$src get [dict get $e path]]
        }
    }
}
copyTree $src /docs $dst /home/me/docs
```

## Check capabilities first

The target must be able to write, and a ZIP source is read-only. Ask `caps`
before you act, so you fail early with a clear reason instead of mid-copy:

```tcl
if {"get" ni [$src caps]} { error "source cannot read" }
if {"put" ni [$dst caps]} { error "target is read-only" }
```

## Avoid clobbering

`put` overwrites. To keep an existing target file, pick a free name first:

```tcl
proc uniqueName {prov dir name} {
    set path [file join $dir $name]
    if {[catch {$prov stat $path}]} { return $path }   ;# free
    set base [file rootname $name] ; set ext [file extension $name]
    set n 1
    while {1} {
        set cand [file join $dir "$base (copy[expr {$n==1?"":" $n"}])$ext"]
        if {[catch {$prov stat $cand}]} { return $cand }
        incr n
    }
}
set to [uniqueName $dst /home/me [file tail /docs/readme.txt]]
$dst put $to [$src get /docs/readme.txt]
```

## In an application

The Explorer framework's `cufileops` controller does exactly this for Copy/Paste
in a GUI: its clipboard remembers the *source provider*, so pasting into a view
backed by a different provider triggers the cross-provider `get`+`put` path --
including the recursive directory copy and the collision handling above. See the
`ctrlutils` repo for that controller.

## See also

- Module reference: [`../tuprovider.md`](../tuprovider.md)
- [howto-provider-backend.md](howto-provider-backend.md)
- [howto-browse-zip.md](howto-browse-zip.md)
