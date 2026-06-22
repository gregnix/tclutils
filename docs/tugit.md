# tclutils::tugit

Parses a Mermaid `gitGraph` into a `tclutils::tudiagram` model (best-effort), so
it can render natively (SVG or PNG) through the pure-Tcl engine — no browser. It
is one of the graph-type parsers the `tclutils::tuflow` facade dispatches to;
you normally call `tuflow::toPng` / `tuflow::toSvg` rather than this module
directly.

## Package

```tcl
package require tclutils::tugit 0.1
```

## Commands

```tcl
::tclutils::tugit::parse text      ;# -> tudiagram model dict
```

The result is a `tudiagram` model and is rendered with
`tclutils::tudiagram::toSvg` / `toPng` (or via the `tuflow` facade).

## Supported syntax (Mermaid subset)

```text
commit                    -> a commit node on the current branch
commit id: "X" tag: "T"   -> node labelled X (the tag is appended)
branch <name>             -> create a branch from the current HEAD, switch to it
checkout <name>           -> switch the current branch
merge <name>              -> a merge commit with two parents (current HEAD and
                             <name>'s HEAD)
cherry-pick id: "X"       -> a commit node on the current branch
```

Commits become nodes; an edge runs from each parent commit to its child. The
default branch is `main`; the direction is `LR` unless the header says
`gitGraph TB:`.

## Usage

```tcl
package require tclutils::tugit
package require tclutils::tudiagram

set src {gitGraph
   commit
   commit id: "Normal" tag: "v1.0"
   branch develop
   checkout develop
   commit
   checkout main
   merge develop
}
set m [::tclutils::tugit::parse $src]
::tclutils::tudiagram::writePng $m git.png -scale 3
```

## Notes

- v1 limitations (honest): the characteristic branch lanes / swimlanes of a git
  graph are NOT drawn — `tudiagram` lays the commits out as a generic
  left-to-right DAG, so the parent/merge topology is preserved but the per-branch
  rows are not. Commit `type:` styling and branch colours are ignored; commit
  nodes are `rounded`, merge nodes are `box`.
- Companion: `tclutils::tudiagram` (renderer), `tclutils::tuflow` (dispatch).

## Error codes

`-errorcode {TCLUTILS TUGIT <REASON>}` — `EMPTY` (no commits found).
