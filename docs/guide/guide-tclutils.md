# tclutils — overview

Pure-Tcl utility library (Tk-free), umbrella `tclutils` 0.68.0. Each module
ships as a `.tm` under `lib/tm/tclutils/` in the `tclutils::<module>` namespace.
Four provider classes live in `lib/tm/tclutils/tuprovider/`. Thin CLI
front-ends live in `bin/`.

## Where things live

- **Module API**: `docs/<module>.md`, one file per module. Man pages:
  `man/mann/<module>.n`, generated from those files. Tests:
  `tests/<module>.test`.
- **This folder** is the cross-module guide, not a second copy of the API.
- **Handbook**: `docs/handbook/de/Tclutils-de.pdf` (German) and
  `docs/handbook/en/Tclutils-en.pdf` (English), one PDF each, built from
  the book sources with bookkit. Same release as the library (0.68.0).

| File | Role |
|---|---|
| [`architecture.md`](architecture.md) | Categories and how the layers fit |
| [`module-status.md`](module-status.md) | One row per module: scope, not a changelog |
| [`coreutils-mapping.md`](coreutils-mapping.md) | Unix tool to module |
| [`cli.md`](cli.md) | The `bin/*.tcl` wrappers |
| [`roadmap.md`](roadmap.md) | What shipped and what is still open |
| [`todo-output.md`](todo-output.md) | Backlog for export bridges |
| [`tudeploy-0.1-spec.md`](tudeploy-0.1-spec.md) | Design record of `tudeploy` 0.1. The API is [`../tudeploy.md`](../tudeploy.md) |
| [`howto-provider-backend.md`](howto-provider-backend.md) | Write a storage backend |
| [`howto-browse-zip.md`](howto-browse-zip.md) | Browse a ZIP as a tree |
| [`howto-cross-provider-copy.md`](howto-cross-provider-copy.md) | Copy between providers |
| [`build-app-guide.md`](build-app-guide.md) | Pointer. The guide lives with the app |
| [`build-app.md`](build-app.md) | Same pointer, older path |
| [`build-app-app-conventions.md`](build-app-app-conventions.md) | Pointer to the app conventions |

`tclutils.md` in this folder is the previous copy of this page.

The build-app text stays in
[`apps/build-app/doc/`](../../apps/build-app/doc/build-app-guide.md). A full
second copy does not belong here.

## Loading modules

From a standard install, `package require tclutils::<module>` is enough.
Otherwise:

```tcl
tcl::tm::path add /path/to/tclutils/lib/tm
package require tclutils::tucsv
```

`source` of [`tools/setup.tcl`](../../tools/setup.tcl) adds `lib/tm` for
tclutils and tkutils. The search order is
[`tools/setup.md`](../../tools/setup.md). `TCLUTILS_TM` overrides it and wins.
On Windows the two places that are meant to hit are that variable and
`lib/tm` next to the file you source. `/usr/local/share/tcltk/...` is looked
up on the current drive, and the per-user path is used only when `HOME` or
`XDG_DATA_HOME` is set.

tclutils modules are found on `tcl::tm::path`. Packages with a `pkgIndex.tcl`,
such as Glyphs, are found on `auto_path`.

History of the tree: [`CHANGELOG.md`](../../CHANGELOG.md).
Runnable scripts: [`examples/README.md`](../../examples/README.md).
