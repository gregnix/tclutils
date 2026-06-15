# tclutils::tudeploy

Runtime discovery and loading of Tcl module packages from application-relative
deployment roots (`vendor/`, `libs/common/`, `libs/`, `lib/tm/`), plus locating
bundled resource directories for external binaries (decoders, tools). Generalises
the recurring "add candidate roots to `tcl::tm::path`, then `package require`"
idiom every bundled app reimplements. Pure Tcl, library-neutral.

The ensemble command is the fully-qualified namespace, so call it as
`::tclutils::tudeploy <sub>` or make a short alias:

```tcl
interp alias {} tudeploy {} ::tclutils::tudeploy
```

## API

```tcl
::tclutils::tudeploy baseDirs
::tclutils::tudeploy platformTag
::tclutils::tudeploy roots          ?-base {d ...}? ?-env {V ...}? ?-roots {rel ...}? ?-parents 0|1?
::tclutils::tudeploy addModulePaths ?-base {d ...}? ?-env {V ...}? ?-roots {rel ...}? ?-parents 0|1?
::tclutils::tudeploy require pkgs   ?-base {d ...}? ?-env {V ...}? ?-roots {rel ...}? ?-parents 0|1? ?-tmadd 0|1? ?-fail 0|1?
::tclutils::tudeploy resourceDirs name ?-base {d ...}? ?-env {V ...}? ?-parents 0|1? ?-tag <str>?
::tclutils::tudeploy sourceModule pkg ?-dirs {d ...}? ?-base {d ...}? ?-env {V ...}? ?-roots {rel ...}? ?-parents 0|1? ?-fail 0|1?
```

- `baseDirs` — the application base directories: the directory of the main
  script (`argv0`) and of the running executable; normalized, de-duplicated,
  existing only. Override anywhere with `-base`.
- `platformTag` — `"<os><bits>"`, e.g. `linux64`, `windows64`, `macos64`.
- `roots` — ordered list of EXISTING module roots, relative to each base dir
  (and its parent, unless `-parents 0`), following `-roots` (default
  `vendor`, `libs/common`, `libs`, `lib/tm`). `-env` directory values are
  prepended. A root holds package subdirs, i.e. `<root>/<pkg>/<mod>-<ver>.tm`.
- `addModulePaths` — add the `roots` to `tcl::tm::path`; returns the added list.
- `require` — `addModulePaths` (unless `-tmadd 0`), then `package require` each
  package in `pkgs`. Returns 1 iff all succeed, else 0; with `-fail 1` it throws
  `{TCLUTILS TUDEPLOY REQUIRE}` instead.
- `resourceDirs` — ordered list of EXISTING candidate directories for a bundled
  resource `name`: per base dir (+ parent) `vendor/<name>/<tag>`,
  `vendor/<name>`, `vendor/<tag>`, `vendor`, `bin`, and the base dir itself.
  Feed the result to `tuexe::find -dirs`, or glob it yourself for non-executable
  resources. `-tag` overrides the platform tag.
- `sourceModule` — load `pkg` by sourcing its module file directly, bypassing
  `tcl::tm` discovery. Searches the resolved dirs (`-dirs`, else `roots` of the
  given `-roots`/`-base`/`-env`) for `<tail>-<ver>.tm` (tail = last `::`
  component), sources the highest version, and verifies the package became
  present. Returns 1/0, or throws `{TCLUTILS TUDEPLOY REQUIRE}` with `-fail 1`.
  Use this for packages whose vendored `.tm` sits at a path that does not match
  its package name — e.g. a bare package `qpdf` shipped as
  `vendor/qpdf/lib/qpdf-0.2.tm` with sibling shared libraries: a dedicated tm
  root `vendor/qpdf/lib` would be a descendant of the shared `vendor` root, and
  `tcl::tm::path add` refuses ancestor/descendant paths. Sourcing the file in
  place avoids the conflict and keeps the module's relative paths intact.

```tcl
interp alias {} tudeploy {} ::tclutils::tudeploy

# load an app's bundled module packages (bundled wins over a system copy)
if {![tudeploy require {somelib::widgeta somelib::widgetb otherlib::helper}]} {
    error "required modules not found"
}

# find a bundled decoder, falling back to PATH (tuexe does the matching)
set dirs [tudeploy resourceDirs webp -env MYAPP_WEBP]
set exe  [::tclutils::tuexe::find dwebp -dirs $dirs]
```

```tcl
# load a package whose vendored layout doesn't match its package name
tudeploy sourceModule qpdf -env QPDF_TM -roots {{vendor qpdf lib} {qpdf lib}}
```

Because `tudeploy` itself lives in this library, an application must first make
the library loadable. A minimal inline stub (run once at the app's top level)
adds the candidate roots to `tcl::tm::path`, after which
`package require tclutils::tudeploy` succeeds and the rest is delegated:

```tcl
apply {{} {
    set bases [list [file dirname [file normalize [info script]]]]
    catch { lappend bases [file dirname [file normalize [info nameofexecutable]]] }
    foreach b $bases {
        foreach rel {vendor {libs common} libs {lib tm}
                     {.. vendor} {.. libs common} {.. libs}} {
            set d [file join $b {*}$rel]
            if {[file isdirectory $d]} { catch {tcl::tm::path add $d} }
        }
    }
}}
package require tclutils::tudeploy
```

## Errors

Carries `{TCLUTILS TUDEPLOY <REASON>}`: `OPTION` (unknown option / missing
value), `USAGE` (missing required argument), `REQUIRE` (with `-fail 1`, a
package could not be loaded).

## Demo

```bash
tclsh examples/demo-tudeploy.tcl
```
