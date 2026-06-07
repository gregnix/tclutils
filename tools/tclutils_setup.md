# setup.tcl (tclutils) — making the tclutils/tkutils libraries discoverable

This file is identical to the file of the same name in the tkutils package: it
searches upward from its own location and adds **both** libraries (tclutils and
tkutils) to the Tcl module path — tkutils depends on tclutils. It therefore does
not matter whether it is sourced from `tclutils-*/tools/` or `tkutils-*/tools/`.

`setup.tcl` is a small bootstrap that tells Tcl where the `tclutils` and
`tkutils` libraries live. After that, `package require` works in your own
application without any further path setup. This file ships inside the package
under `tclutils-<version>/tools/` (and likewise with tkutils) so that it is not
lost.

## Why it is needed

tclutils and tkutils are **Tcl modules** (`tcl::tm`). Tcl only finds a module
when the matching `lib/tm` directory is on the module search path. By default
Tcl searches only fixed system paths (see `tcl::tm::path list`) — a freshly
unpacked library is not among them. Without this step you get "can't find
package …" or "library not found" at startup.

`setup.tcl` performs exactly this one step: for each library it calls
`tcl::tm::path add <…/lib/tm>`, each time for the highest version found.

## Placement

`setup.tcl` may live in two places — both are detected automatically:

**a) inside the package** (as shipped), so that it is not lost:

```
~/lib/tcltk/
├── tclutils-0.53.0/
│   ├── tools/
│   │   ├── setup.tcl
│   │   └── setup.md
│   └── lib/tm/…
└── tkutils-0.40.0/
    └── lib/tm/…
```

**b) directly next to the library folders:**

```
~/lib/tcltk/
├── setup.tcl
├── tclutils-0.53.0/
└── tkutils-0.40.0/
```

In both cases `setup.tcl` searches **upward** from its own location until it
finds a directory that contains `tclutils-*`/`tkutils-*` folders. Several
versions may sit side by side — the **highest** one is chosen automatically.

## Usage in your application

Source `setup.tcl` at the very top of your app, then load the packages you need:

```tcl
# variant a) from inside the package:
source ~/lib/tcltk/tclutils-0.53.0/tools/setup.tcl

# variant b) directly next to the libraries:
# source ~/lib/tcltk/setup.tcl

package require tclutils::tubin
package require tkutils::tkucsv
```

Both libraries are added to the module path because tkutils uses tclutils
internally. A GUI program then enters the event loop as usual.

## What setup.tcl does exactly

```tcl
apply {{} {
    set dir [file dirname [file normalize [info script]]]
    set base $dir
    for {set i 0} {$i < 6} {incr i} {
        if {[llength [glob -nocomplain -directory $dir -type d tclutils-* tkutils-*]] > 0} {
            set base $dir
            break
        }
        set parent [file dirname $dir]
        if {$parent eq $dir} break
        set dir $parent
    }
    foreach lib {tclutils tkutils} {
        foreach d [lsort -decreasing -dictionary \
                [glob -nocomplain -directory $base -type d ${lib}-*]] {
            set tm [file join $d lib tm]
            if {[file isdirectory $tm]} {
                tcl::tm::path add $tm
                break
            }
        }
    }
}}
```

- `info script` → the directory of `setup.tcl` itself. **No absolute paths are
  hard-wired**; everything is relative to this file.
- The loop walks up to 6 levels upward until it finds the root directory with
  the library folders (this covers both the `tools/` and the side-by-side
  layout).
- Per library the `tclutils-*` / `tkutils-*` folders are sorted by version in
  descending order (`-dictionary`, so that `0.10 > 0.9`); the first one with an
  existing `lib/tm` is added.
- `-type d` ignores `.zip` files and the like. The `apply` block leaves no
  helper variables behind in the global namespace.

## Alternative without setup.tcl

If you would rather not put the `source` line into every app, copy the
**contents** of `lib/tm` (that is, the umbrella file `tclutils-0.53.0.tm`
**and** the `tclutils/` folder) into one of the directories that
`tcl::tm::path list` already lists. Then a plain `package require` works with no
path step at all.

## What not to do

Do **not** rename the module files to `tclutils::common-0.1.tm` (with `::`).
The tm lookup maps `tclutils::common` to the path `tclutils/common-0.1.tm`
(subfolder) — it does not find flat `::` names. The subfolder layout of the
shipped archives must be preserved.

## Quick diagnosis for "library not found"

1. Does `setup.tcl` live in the package under `tclutils-*/tools/` or next to the
   `tclutils-*`/`tkutils-*` folders?
2. Does the chosen version contain the path `…/lib/tm/tclutils/` with the
   `*.tm` files (subfolder layout, not renamed flat)?
3. Test: after `source setup.tcl`, run `puts [tcl::tm::path list]` once — the two
   `lib/tm` paths must appear.
4. For development inside the source tree the path can also be set via the
   environment variable `TCLUTILS_TM` (the libraries' tests/demos use it).
