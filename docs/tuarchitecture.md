# tclutils::tuarchitecture

Parses a Mermaid `architecture-beta` block into a `tclutils::tudiagram` model so
an architecture diagram renders natively (SVG or PNG) through the pure-Tcl
engine everywhere -- no browser. Like `tuc4`, this is a **graph parser**: it
only builds a model; layout and rendering are done by `tudiagram`. Normally you
call `tuflow::toSvg` / `tuflow::toPng`, which detect the `architecture-beta`
header, parse here, and lay the graph out.

## Package

```tcl
package require tclutils::tuarchitecture 0.1
```

## Commands

```tcl
::tclutils::tuarchitecture::parse text   ;# -> tudiagram model dict
```

Render the returned model with the tudiagram backends:

```tcl
::tclutils::tudiagram::toSvg  model
::tclutils::tudiagram::toPng   model ?-scale n?
::tclutils::tudiagram::writeSvg model file
::tclutils::tudiagram::writePng model file
```

## Supported syntax (Mermaid subset)

```text
architecture-beta
  group <id>(<icon>)[<Label>]            -> a group, drawn as a cluster frame
  service <id>(<icon>)[<Label>] in <g>   -> a service node (`in <group>` optional)
  junction <id>                          -> a routing point (drawn as a dot)
  <id>:<S> -- <S>:<id>                    -> edge, no arrowhead
  <id>:<S> --> <S>:<id>                   -> edge, arrowhead at the target
```

- The header is `architecture-beta` (bare `architecture` is also accepted).
- The display label is the `[Label]`, or the id if absent.
- `<S>` is a side hint `L|R|T|B`; `--` / `-->` / `<--` / `<-->` choose the
  arrowheads (none / end / start / both).
- Edge endpoints that were never declared are created as plain boxes, so an edge
  to an as-yet-undeclared id still renders.
- Blank lines and `%%` comments are ignored.

## Icons -> shapes

There is no external icon set; the `(icon)` maps to a tudiagram node shape so
families stay readable:

| icon | shape |
|------|-------|
| `database`, `db`, `disk`, `storage` | cylinder |
| `cloud`, `internet` | rounded |
| `server` and anything else | box |

## v1 limitations (honest)

- **Groups draw as cluster frames** (needs `tudiagram` >= 0.4). A `group` becomes
  a labelled box around the bounding box of its `in <group>` members; nested
  `group ... in <parent>` is honoured (members roll up). The frame is a post-hoc
  bounding box over the laid-out members, so it is tight when a group is a
  connected sub-cluster and looser when the layout scatters them. A group id that
  an edge references is
  drawn as a plain node.
- **Side hints are not routed.** `:L :R :T :B` are parsed but do not steer the
  edge ports -- the engine decides port positions (the same limitation as
  `tuc4`'s `Rel_U/D/L/R` hints). The declared topology survives; the exact
  approach side may differ from Mermaid.
- **Icons are shapes, not glyphs** (no Iconify dependency).

## mermaid.js compatibility (read this before using a ```mermaid``` fence)

There are **two independent parsers** for the same fence content. A raster sink
(PDF, ODT, Tk, or a ```flow``` fence) renders through `tuflow -> tuarchitecture`.
An HTML export with `enableMermaid 1` hands a ```mermaid``` block to **mermaid.js**
in the browser instead. `tuarchitecture` accepts a **lenient superset** of
mermaid.js `architecture-beta`, so a block that renders here can still throw
`Syntax error in text` in a browser running mermaid.js 11.x.

Everything in the **official mermaid examples renders identically here** (verified
against `tuflow::toSvg`/`toPng`): write that subset and a ```mermaid``` block works
in **both** paths.

Safe-subset checklist (renders in mermaid.js **and** tuflow):

- Header `architecture-beta`.
- `group id(icon)[Label]` and `service id(icon)[Label]`, optional `in <group>`
  (groups may nest: `group inner(icon)[..] in outer`).
- Built-in icons only: `cloud`, `database`, `disk`, `internet`, `server` (or a
  registered iconify pack like `logos:aws-lambda`).
- Edges `a:S -- S:b` with sides `T|B|L|R`; arrowheads `-->`, `<--`, `<-->`. The
  cross-group modifier `a{group}:S --> S:b{group}` is tolerated here (the modifier
  is stripped; the edge still connects).
- **Declare every id before an edge references it.**
- Keep ids to plain `[A-Za-z0-9_]`; prefer simple, single-word labels. Labels with
  spaces appear in the official examples (`[Cloud Infrastructure]`); other
  characters (hyphens, slashes, umlauts) are **not guaranteed** by mermaid.js and
  are a common cause of its "Syntax error".

If you need an architecture diagram in HTML that does **not** depend on mermaid.js,
use a ```flow``` fence: docir then renders inline SVG via `tuflow`, identical to
the PDF output. (A docir-side alternative is to treat `architecture-beta` as
native when `tuflow::toSvg` succeeds, instead of delegating to mermaid.js.)



```tcl
package require tclutils::tuarchitecture
set src {architecture-beta
    group tier(cloud)[Application Tier]
    service web(server)[Web UI] in tier
    service api(server)[API] in tier
    service db(database)[Database] in tier
    web:R -- L:api
    api:B -- T:db}
::tclutils::tudiagram::writePng [::tclutils::tuarchitecture::parse $src] arch.png -scale 3
```

In Markdown, `architecture-beta` rides on the ```` ```mermaid ```` fence, so
docir's raster sinks (pdf / odt / rendererTk) render it through `tuflow::toPng`;
no docir change is needed.

## Notes

- Companion: `tclutils::tudiagram` (layout + render), `tclutils::tuflow`
  (dispatch). `tuflow::parse` delegates `architecture-beta` here and returns the
  tudiagram model, exactly like `mindmap` / `C4*` / `gitGraph`.
- Because it is a graph type, the same model also flows through every other
  tudiagram consumer unchanged.

## Error codes

`-errorcode {TCLUTILS TUARCHITECTURE <REASON>}` -- `EMPTY` (no services; a
diagram consisting only of empty groups also yields no nodes).
