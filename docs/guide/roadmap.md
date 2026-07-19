# Roadmap

For the per-module scope status see [`module-status.md`](module-status.md);
the wishlist/backlog detail lives with the reviews. This file is the
high-level history and forward view.

_As of 2026-07-19: 133 modules; hygiene gate green (test 137, doc 133, man 134,
0 duplicate-version). Umbrella `tclutils` 0.61.0; recommended pairing
tclutils 0.61.0 + tkutils 0.43.0._

## Recently shipped

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
