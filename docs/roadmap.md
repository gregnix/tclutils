# Roadmap

For the per-module scope status see [`module-status.md`](module-status.md);
the wishlist/backlog detail lives with the reviews. This file is the
high-level history and forward view.


## Planned / backlog

Extensions to existing modules:

- `tutail`: `-f` (follow) for log workflows.
- `tucut`: byte/character mode `-c`.
- `tujoin`: outer join (`-a`/`-v`).
- `tused`: more address forms.
- `tugrep`: `-w`, `-x`, `-m`, multiline.

New modules under consideration:

- `tuyaml` (config/frontmatter alongside `tujson`).
- `tumime`, `tutoml`, `tutime` (P2).

Output/export bridges (text/csv/json/pdf/odf) — see
[`todo-output.md`](todo-output.md). GUI inspectors (`pdfinspect`,
`odfinspect`, `mdview`) are tracked in the **tkutils** roadmap.

## Deliberately out of scope


- A full PDF parser, full ODF implementation, or full CommonMark engine —
  inspectors/helpers only.
- Destructive filesystem clones (`rm`, `mv`, `cp`).
- Re-implementing `tar` — use tcllib `tar`.
