# check-modules.tcl

Module hygiene check and manifest generator for the `tclutils` / `tkutils`
module collections.

It scans one repository's module tree (`lib/tm/<repo>/<mod>-X.Y.tm`) and reports,
per module, which companion artifacts exist (tests, docs, man pages, …). It can
also emit a machine-readable manifest (TSV or Markdown) listing every module with
its version, description and dependencies.

## Synopsis

```
tclsh tools/check-modules.tcl [repo-root] [-require test,doc,man,...] [-manifest tsv|md]
```

- `repo-root` — repository root to scan. Defaults to the parent of the script's
  directory. The module directory is `lib/tm/<repo>` where `<repo>` is the tail
  of the root (e.g. `tkutils`). If that directory does not exist but `lib/tm`
  contains exactly one subdirectory, that one is used.
- `-require <list>` — comma- (or space-) separated subset of
  `{test doc man bin demo umbr}`. Default `test,doc,man`. Drives the REQUIRED gap
  list and the exit code.
- `-manifest <fmt>` — emit a manifest instead of the human-readable report.
  `<fmt>` is `tsv` or `md`.
- `-h`, `-help` — print usage and exit.

## What it checks

For each module `<mod>` the following artifacts are looked up relative to the
repo root:

| Flag | Artifact | Path |
|---|---|---|
| `VER`  | version uniqueness | a single `<mod>-X.Y.tm` (more than one is an error) |
| `TEST` | unit tests | `tests/<mod>.test` |
| `DOC`  | documentation | `docs/<mod>.md` |
| `MAN`  | man page | `man/mann/<mod>.n` or `man/man1/<mod>.1` |
| `BIN`  | CLI launcher | `bin/<mod>.tcl` |
| `DEMO` | example | `examples/demo-<mod>.tcl` |
| `UMBR` | listed in umbrella | `package require <repo>::<mod>` in `lib/tm/<repo>-*.tm` |

## Human-readable report (default)

Prints a matrix (one row per module, Y / `.` flags), a totals line, and three
sections:

- **Duplicate-version modules** — modules with more than one `.tm` version
  (must be unique).
- **Missing REQUIRED artifacts** — gaps among the `-require` set; these are
  actionable.
- **Other gaps** — `bin` / `demo` / `umbr` absences not in the required set;
  these are often intentional (pure-library modules have no CLI or GUI; optional
  modules are deliberately kept out of the umbrella).

Example:

```
$ tclsh tools/check-modules.tcl ../tkutils -require test,doc,man
Module hygiene check: tkutils
Root:     /home/greg/lib/tcltk/tkutils
Umbrella: tkutils-0.42.tm (37 modules listed)
Required: test doc man

NAME                 VERSION    TEST DOC  MAN  BIN  DEMO UMBR
------------------------------------------------------------
tkurender            0.1        Y    Y    Y    .    .    Y
...
```

## Manifest mode

With `-manifest`, the human report is suppressed and a manifest is written to
stdout. All diagnostics (warnings, errors) go to **stderr**, so stdout stays a
clean, pipeable manifest.

### Columns

```
package  version  description  test  doc  man  repo  path  deps
```

- `package` — full package name, `<repo>::<mod>`.
- `version` — every version found, comma-joined (normally one).
- `description` — read from a `# Description: ...` header line in the module's
  `.tm` file (case-insensitive, flexible whitespace; empty if absent).
- `test` / `doc` / `man` — `Y` / `N`.
- `repo` — `tclutils` or `tkutils`.
- `path` — path to the highest-version `.tm`, relative to the repo root.
- `deps` — the module's `package require` targets (comma-joined): internal
  collection modules (e.g. `tclutils::tulayout`) and external packages (e.g.
  `pdf4tcl`, `sqlite3`) alike. `Tcl`, `Tk` and the module's own package are
  excluded. Comment lines are ignored; `-exact` and requires nested in
  `catch` / `if` are recognized. Dependencies are derived by static text
  analysis, so dynamically assembled package names are not detected.

### Formats

- `tsv` — tab-separated, one header row plus one row per module.
- `md` — a Markdown table (header + separator + rows). `package` and `path` are
  rendered as inline code; `|` characters inside a description are escaped.

### The `# Description:` convention

To populate the `description` column, add a single header line near the top of
each module:

```tcl
# tkurender.tm
# Description: Shared render core -- widget catalogue, in-memory model, serialize
package provide tkutils::tkurender 0.1
```

Keep it to one concise line.

## Examples

Generate a TSV manifest for one repository:

```sh
tclsh tools/check-modules.tcl ../tkutils -manifest tsv > tkutils-modules.tsv
```

Generate a Markdown table:

```sh
tclsh tools/check-modules.tcl ../tkutils -manifest md > tkutils-modules.md
```

Combine two repositories into one manifest (drop the second header — TSV has a
1-line header, MD has a 2-line header):

```sh
tclsh tools/check-modules.tcl ../tclutils -manifest tsv            > modules.tsv
tclsh tools/check-modules.tcl ../tkutils  -manifest tsv | tail -n +2 >> modules.tsv

tclsh tools/check-modules.tcl ../tclutils -manifest md            > modules.md
tclsh tools/check-modules.tcl ../tkutils  -manifest md | tail -n +3 >> modules.md
```

## Exit code

- `0` — all modules unique and no REQUIRED artifact missing.
- `1` — at least one module has multiple versions, or lacks a required artifact.
- `2` — usage error (unknown option, unknown manifest format, module dir not
  found).

The exit code is the same in manifest mode, so a manifest run still signals
hygiene problems (the manifest itself goes to a redirected file, unaffected by
the exit status).
