# tclutils::tuzipfs

`tclutils::tuzipfs` is a small Tcl 9 `zipfs` convenience wrapper. The package
loads under Tcl 8.6 as well, but commands that need `zipfs` throw a clear
`TCLUTILS TUZIPFS UNAVAILABLE` error.

Since 0.2 it also provides a handful of **image primitives** for assembling
self-contained Tcl 9 applications (zipkits) with `zipfs mkimg`.

## Commands

```tcl
package require tclutils::tuzipfs

::tclutils::tuzipfs::available
::tclutils::tuzipfs::requireAvailable
::tclutils::tuzipfs::root
::tclutils::tuzipfs::mounts
::tclutils::tuzipfs::mount archive.zip ?mountName?
::tclutils::tuzipfs::unmount mountpoint
::tclutils::tuzipfs::listFiles mountpoint ?-glob pattern? ?-recursive boolean?
::tclutils::tuzipfs::find mountpoint ?options?
::tclutils::tuzipfs::exists zipfsPath
::tclutils::tuzipfs::readFile zipfsPath
::tclutils::tuzipfs::withMounted archive.zip mountVar body ?-mount mountName?
```

## Image primitives (0.2)

```tcl
::tclutils::tuzipfs::rcopy src dst
::tclutils::tuzipfs::copyStdlib destDir ?-tk boolean? ?-from running|DIR?
::tclutils::tuzipfs::mkimg outfile indir ?-strip DIR? ?-basekit FILE? ?-password PW?
::tclutils::tuzipfs::buildImage -out FILE -vfs DIR ?-basekit FILE? ?-stdlib none|cli|gui? ?-stdlibfrom running|DIR?
```

- `rcopy` — recursive byte-exact copy. Works from a mounted `zipfs` source,
  where a plain `file copy` is unreliable.
- `copyStdlib` — copy `tcl_library` (and, with `-tk 1`, `tk_library`) into
  `destDir`. `-from running` uses the current interpreter's `[info library]` /
  `$::tk_library`; `-from DIR` reads them from `DIR/tcl_library` (and
  `DIR/tk_library`) — point this at a foreign basekit's mountpoint for
  cross-platform builds.
- `mkimg` — checked wrapper over `zipfs mkimg`. Files in `indir` land at the
  image's archive root because `-strip` defaults to `indir`. `-basekit` is the
  template interpreter (default: the running executable, which must itself be a
  static zipkit).
- `buildImage` — one-call convenience: optionally drop the stdlib into an
  already-assembled VFS tree (`-stdlib cli|gui`), then `mkimg`.

## Example — read from an archive

```tcl
tcl::tm::path add lib/tm
package require tclutils::tuzipfs

if {[::tclutils::tuzipfs::available]} {
    ::tclutils::tuzipfs::withMounted document.odt mp {
        puts [::tclutils::tuzipfs::listFiles $mp -glob *.xml]
        puts [::tclutils::tuzipfs::readFile [file join $mp content.xml]]
    }
}
```

## Example — build a standalone application

```tcl
package require tclutils::tuzipfs
namespace import ::tclutils::tuzipfs::*

# Assemble a VFS tree: the app as main.tcl at the archive root.
file mkdir app.vfs
file copy myapp.tcl [file join app.vfs main.tcl]

# Add the standard library and build the image onto a static basekit.
# (mkimg REPLACES the basekit's own attached archive, so the stdlib must be
#  carried in the VFS tree -- see Notes.)
buildImage -out myapp -vfs app.vfs -basekit basekit-tcl -stdlib cli
```

For the full application builder (dependency probing, GUI bootstrap,
cross-platform), see the `build-app` app and `docs/guide/build-app.md`.

## Notes

`zipfs mkimg` replaces the ZIP archive attached to the basekit. A BAWT or
magicsplat basekit ships its own standard library inside that archive (mounted
at `//zipfs:/app/tcl_library`); an image built with only the application would
lose the stdlib and fail to start. Always put `tcl_library` (and `tk_library`
for Tk apps) into the VFS tree first — `copyStdlib` does this.

`zipfs` is part of Tcl 9. For Tcl 8.6 or for byte-level ZIP creation and ODF
container control, use `tclutils::tuzip` instead.
