# Roadmap

For the per-module scope status see [`module-status.md`](module-status.md);
the wishlist/backlog detail lives with the reviews. This file is the
high-level history and forward view.

_As of 2026-10-28: 146 module files under `lib/tm/tclutils/` (140 flat
modules and four provider classes), plus the umbrella `tclutils` 0.69.0.
Recommended pairing: tclutils 0.69.0 + tkutils 0.49.0 + ctrlutils 0.5.
Each module has `docs/<module>.md` and a man page under `man/mann/`._

_Done since 2026-07-19 and not repeated in the backlog: the storage
providers (`tuprovider` + zip/dav/ftp/sftp), `tupostgrest`, `tutdbc`,
`tudhash`, `tuxxhash`, `tunotesdb`, the diagram family behind `tuflow`,
in 0.63.0 the HTTPS verification through `tuhttps`, in 0.64.0
`tusettings`, `tutestrun` and `tupkgfinder` 0.2, in 0.66.0 `tutask` 0.2,
and in 0.67.0 `tupdftext`._

## Recently shipped

- **`tupdftext` (0.67.0).** Page text from a PDF in pure Tcl, for full-text
  search. Structure stays in `tupdf`. No decryption, no OCR, no column layout.
- **`tutask` 0.2 (0.66.0).** Requires `common` 0.2. Pool and group errors from
  0.1 are fixed, and `-timeout` is checked on `run`, `wait` and `await`.
- **`tutask` (0.65.0).** Tasks on coroutines: `await` with timeout, `cancel`
  that runs the task's `finally` and cancels the awaited operation, groups
  (`all` fail-fast, `first`), operations `timer`/`pipe`/`onwrite`, a thread
  pool (Thread package, loaded on first use) and a sandbox (safe interp with
  command and time limits). 68 tests on 8.6 and 9, checked against injected
  faults; `examples/demo-task.tcl` with a Tk part.
- **`tujoin` anti-join.** Added `-anti left|right|both` (unmatched-only rows,
  mutually exclusive with `-outer`). Version → 0.1.1, tests `tujoin-3.1`…`3.6`.
- **`tugrep` matching options.** Added `-word` (whole-word, like grep `-w`),
  `-wholeline` (whole-line, `-x`) and `-max N` (stop after N matches, `-m`).
  Version → 0.1.2, tests `tugrep-3.1`…`3.9`.
- **`tused` address forms.** Added negation (`addr!cmd`) and step
  (`first~step`); the GNU-style address set (line, `$`, `/regex/`, ranges) is now
  complete. Version → 0.1.3, with new tests `tused-2.5`…`2.11`.
- **Repository hygiene & metadata.** `# Description:` + `# Category:` headers on
  all modules of that release (128 at the time); `README.md` and
  `module-status.md` cover them completely; a
  unified path resolver `tools/setup.tcl` (env / install / share / XDG /
  side-by-side, versioned or not). `check-modules.tcl` gained a category column,
  UTF-8 manifest output and an optional `-title`, plus the
  `check-modules-gui.tcl` Tk front-end. `tulayout` man page added — hygiene gate
  back to green, and `tulayout` added to the umbrella alongside its pure-Tcl
  graphics siblings `tusvg`/`tupngdraw`/`tupng`.
- Optional net/data helpers (the only **not dependency-free** modules):
  `tufetch` (HTTP(S) `get`/`download`, GET/POST; native `http`+`tls` else
  curl/wget), `tusparql` (thin SPARQL client over `tufetch`/`tuurl`/`tujson`),
  and `tusqlite` (NULL-safe `sqlite3` `insert`/`rows`/`value` helpers).

## Planned / backlog

Extensions to existing modules:

- `tutask`: optional process-group kill on Unix (`setsid`, as in the
  concurrency book); a `-quiet` switch for uncollected errors if bgerror
  reporting turns out too noisy.
- `tutail`: `-f` (follow) for log workflows.
- `tugrep`: multiline matching (`-w`/`-x`/`-m` already ship).

New modules under consideration:

- `tuyaml` (config/frontmatter alongside `tujson`).
- `tumime`, `tutoml`, `tutime` (P2).

Tests / quality:

- Synchronize test corpora for `tuodf`, `tupdf`, `tumd`, `tufuzzy`, `tuagrep`.
- Broaden CLI tests as the CLI wrappers grow.

Output/export bridges (text/csv/json/pdf/odf) — see
[`todo-output.md`](todo-output.md). GUI inspectors (`pdfinspect`,
`odfinspect`, `mdview`) are tracked in the **tkutils** roadmap.

## Deliberately out of scope

- A full PDF parser, full ODF implementation, or full CommonMark engine —
  inspectors/helpers only.
- Destructive filesystem clones (`rm`, `mv`, `cp`).
- Re-implementing `tar` — use tcllib `tar`.
- Blanket CLI launchers (`bin`) or demos for every module — both are opt-in,
  added only where a specific module benefits.
- Eager umbrella registration of the diagram family — `tuflow` (itself in the
  umbrella) loads those 22 modules lazily by design.
