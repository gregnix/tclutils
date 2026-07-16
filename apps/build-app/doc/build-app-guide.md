# Building standalone applications (zipkits)

This guide explains how `tclutils` turns an application into a single
self-contained executable for Tcl/Tk 9, how the pieces fit together, and the two
non-obvious facts that make or break a build. The mechanics live in
`tclutils::tuzipfs` (image primitives) and the `build-app` app (orchestration).

![build-app: zipkit build pipeline](build-app-pipeline.svg)

At a glance: the app source is assembled into a VFS tree (with the stdlib and
its modules), `zipfs mkimg` prepends a static basekit and appends that tree, and
the result is a standalone executable that mounts itself at `//zipfs:/app`. The
prober supplies the real dependency set; the choice of basekit decides the
target platform.

## What a zipkit is

On startup Tcl 9 checks whether a ZIP archive is appended to its own
executable, mounts it at `//zipfs:/app`, and — if that archive has a top-level
`main.tcl` — runs it automatically. A "standalone executable" is therefore just:

```
[ static Tcl/Tk 9 interpreter ] [ appended ZIP: main.tcl + app + stdlib ]
```

No unpacking, no temp directory, no installed Tcl. The static interpreter is the
**basekit** (from BAWT or magicsplat); it is the same for every app you build.

## What `zipfs mkimg` does — and the stdlib trap

`zipfs mkimg out vfs strip "" basekit` copies the basekit's bytes to the front
unchanged and appends the contents of `vfs/` as the new ZIP.

The trap: **mkimg replaces the archive already attached to the basekit.** A BAWT
basekit ships its own standard library inside that archive (its `[info library]`
is `//zipfs:/app/tcl_library`). An image built with only the application loses
the stdlib and cannot even reach `init.tcl`. So the VFS tree must carry
`tcl_library` (and, for GUI apps, `tk_library`) itself.

`tuzipfs::copyStdlib` does this. By default `build-app` takes the stdlib from
the **target basekit**: it mounts the basekit read-only and copies the library
trees out with `tuzipfs::rcopy` (a byte-exact recursive copy — plain
`file copy` from a mounted `zipfs` is unreliable). Taking the stdlib from the
target basekit guarantees an exact version match and is what makes
cross-platform builds work from any builder.

## The VFS tree `build-app` assembles

```
build.vfs/
  main.tcl            generated entry point
  tcl_library/        from the target basekit
  tk_library/         (GUI only)
  lib/tm/             bundled tclutils/tkutils module trees (-tm)
  lib/pkgs/           external pkgIndex packages found by the prober (optional)
  app/                the application's own files
  _lib/paths.tcl      bootstrap shim (app family)
```

The generated `main.tcl` does what `wish`/`tclsh` would do implicitly but a
zipkit does not:

- it puts the bundled modules on the module path
  (`tcl::tm::path add //zipfs:/app/lib/tm`);
- it sources the app and, for GUI apps, runs the `-launch` entry (e.g.
  `::notesapp::buildApp .`) and then **holds the event loop open**
  (`vwait forever` plus `WM_DELETE_WINDOW → exit`). Without this the process
  exits the moment `main.tcl` returns — a zipkit does not reproduce wish's
  implicit main loop.

Applications in the tkutils/tclutils family bootstrap their module path with
`source .../_lib/paths.tcl`. In the image that repo-relative file does not
exist, so `build-app` writes a small shim `_lib/paths.tcl` that just adds
`//zipfs:/app/lib/tm` to the module path.

## The dependency-closure prober

Deciding which modules to bundle from a static `package require` scan
over-includes badly: an umbrella like `tkutils` references tablelist, scrollutil,
tksvg, sqlite3, tdom and more, almost all loaded lazily. `build-app` instead
runs the app once under the **target basekit** (with the module trees on the
path) and records the packages that were *actually* loaded. Modules from the
tm trees are bundled via `-tm`; genuinely external pkgIndex packages (sqlite3,
tdbc, tablelist …) are located under the `-extlib` roots and copied into
`lib/pkgs/`. For an app whose closure is tm-only (e.g. notes-app), the prober
correctly bundles nothing extra.

The prober launches the target basekit so GUI apps get a real Tk; that step
needs a display (use `xvfb-run -a` on a headless build host). Use `-probe 0` to
skip it for apps whose external closure you already know to be empty.

## Dependency manifests

The prober's output is a list, and it can be recorded instead of re-derived.
`-writemanifest FILE` runs the prober and also writes the external package
directories to `FILE` (one basename per line, `#` comments allowed).
`-manifest FILE` does the reverse: it skips the prober and bundles exactly the
packages named in `FILE`, resolving each under the `-extlib` roots. That makes a
build reproducible and display-free — useful in CI, and useful when several apps
share a curated dependency list. The manifest is also the natural artifact to
ship if you distribute an app as scripts plus a package list rather than as a
self-contained zipkit: the two are the same closure, written down. Native client
libraries (libpq, the Oracle client) are not Tcl packages, so they never appear
in a manifest and stay a target-system dependency.

## Cross-platform builds

The output platform is decided entirely by `-basekit`. To build a Windows `.exe`
on Linux, pass the Windows basekit as `-basekit`; `zipfs mkimg` prepends the PE
interpreter unchanged and appends the archive. Because the stdlib is taken from
that same basekit (`-stdlibfrom basekit`, the default), it is the Windows stdlib
— the build does not depend on the builder's own platform. The resulting file
starts with `MZ`, is a valid PE, and runs on Windows.

## The self-hosting builder

`build-app` itself is packaged as a zipkit (`apps/bin/build-app-zipkit-linux`)
that carries `tclutils::tuzipfs` embedded. A build host then needs only that one
executable plus the basekits — no installed Tcl, no installed tclutils. `tclutils`
must be present only once, to produce the builder; after that the builder is
self-contained. For a Windows build host, package the builder once onto the
Windows basekit (`build-app.exe`) and the same workflow runs there.

## Minimal build without the app orchestrator

For a trivial app you can drive the primitives directly:

```tcl
package require tclutils::tuzipfs
namespace import ::tclutils::tuzipfs::*

file mkdir app.vfs
file copy myapp.tcl [file join app.vfs main.tcl]
buildImage -out myapp -vfs app.vfs -basekit basekit-tcl -stdlib cli
```

`build-app` adds everything the primitives do not: module bundling, the GUI
bootstrap and event loop, the dependency prober, and the cross-platform stdlib
handling.
