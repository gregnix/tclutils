# tclutils — overview

Pure-Tcl utility library (Tk-free). Each module ships as a `.tm` under
`lib/tm/tclutils/` in the `tclutils::<module>` namespace; thin CLI front-ends
live in `bin/`.

## Where things live
- **Module docs**: `docs/<module>.md` (top level, one per module).
- **General guides** (this folder, `docs/guide/`):
  [`architecture.md`](architecture.md) (categories/design),
  [`module-status.md`](module-status.md) (per-module scope),
  [`coreutils-mapping.md`](coreutils-mapping.md) (Unix-tool mapping),
  [`cli.md`](cli.md) (CLI front-ends),
  [`roadmap.md`](roadmap.md), [`todo-output.md`](todo-output.md),
  [`tudeploy-0.1-spec.md`](tudeploy-0.1-spec.md),
  [`build-app-guide.md`](build-app-guide.md) (standalone-app builder) and
  [`build-app-app-conventions.md`](build-app-app-conventions.md) (rules an app
  must follow to be packageable).
- **Provider-framework HOWTOs** (task recipes for the storage-provider layer):
  [`howto-provider-backend.md`](howto-provider-backend.md) (write a backend),
  [`howto-browse-zip.md`](howto-browse-zip.md) (browse an archive as a tree),
  [`howto-cross-provider-copy.md`](howto-cross-provider-copy.md) (copy between
  providers).
- **Man pages**: `man/mann/<module>.n`. **Tests**: `tests/<module>.test`.

## Loading modules
Installed in a standard location → `package require tclutils::<module>`.
Otherwise add the module directory explicitly:
```tcl
tcl::tm::path add /path/to/tclutils/lib/tm
package require tclutils::tucsv
```
or point `TCLUTILS_TM` at it.
