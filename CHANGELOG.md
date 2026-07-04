# Changelog

## 0.59.0

- Fixed the umbrella typo `tclutis::tulayout` in `tclutils-0.58.0.tm`, which
  broke `package require tclutils` entirely (the umbrella now loads).
- Umbrella now also loads `tuxxhash`, `tudhash` and `tupostgrest`.
- Added man pages for `tudhash` and `tuxxhash`.
- Recommended pairing: tclutils 0.59.0 + tkutils 0.42.0.

## 0.58.0

Adds a Mermaid-compatible diagram subsystem and a MaxMind DB reader; the library
remains pure Tcl and runs on Tcl 8.6 and Tcl 9.x. All diagram rendering uses
primitive operations on a shared abstract canvas, so SVG and PNG output stay
congruent.

- Diagrams -- `tuflow`: the render facade. Detects the diagram language of a
  fenced code block and dispatches -- graph types through a parser into the
  `tudiagram` model (laid out and drawn), non-graph types through a
  self-contained 2D renderer. Requiring it pulls in `tudiagram`; the individual
  parsers and renderers load lazily on first use.
- Diagram model -- `tudiagram` 0.3: abstract graph model, layout and drawing.
  Node shapes box / rounded / circle / stadium / diamond / hexagon / cylinder,
  per-node colour overrides, thick edges, and crow's-foot end-marks
  (exactlyOne / zeroOrOne / oneOrMany / zeroOrMany). All shapes use
  rect / line / polygon / text primitives for portability.
- Graph parsers (Mermaid subset -> `tudiagram`): `tustate` (stateDiagram),
  `tuer` 0.2 (erDiagram, crow's-foot), `tuclass` (classDiagram),
  `turequirement` (requirementDiagram), `tumindmap` (mindmap), `tuc4` (C4),
  `tublock` (block-beta), `tugit` (gitGraph).
- 2D renderers (own parser + render): `tupie` (pie), `tuxychart` (xychart),
  `tuquadrant` (quadrantChart), `tujourney` (journey), `tutimeline` (timeline),
  `tusankey` (sankey-beta), `tugantt` (gantt), `tusequence` (sequenceDiagram).
- Canvas backends: `tusvg` 0.2 gains a Canvas-object constructor (`tusvg::new`);
  `tupngdraw` 0.12. The two share an abstract drawing protocol, so every
  renderer targets both SVG and PNG.
- Geo: `tummdb` -- pure-Tcl MaxMind DB (.mmdb) reader; added to the umbrella.
- Removed `tumermaid` (redundant -- tuflow's flowchart parser produces the same
  output). Cut over tudiagram 0.1 -> 0.3, tuflow 0.1 -> 0.2, tupngdraw 0.11 -> 0.12.
- Recommended pairing: tclutils 0.58.0 + tkutils 0.41.0.

## 0.57.0

Adds one color module; the library remains pure Tcl and runs on Tcl 8.6 and
Tcl 9.x.

- Color: `tucolor` -- named-color database and conversions. Resolves color
  names / `#rgb` / `#rrggbb` / `{r g b}` to RGB, converts to hex and HSV
  (`rgb`, `hex`, `toHsv`, `fromHsv`), lists/checks names (`names`, `exists`) and
  finds the nearest named color (`nearest`). The 148-entry CSS3/X11 name table
  is embedded (generated from Tk's `winfo rgb`, so values match X11/Tk), keeping
  the module GUI-free -- no Tk/X11 at runtime. Complements `tuterm`, `tupng`
  and `tusvg`. Ships with `test`, `doc`, `man` and demo; added to the umbrella.
- Recommended pairing: tclutils 0.57.0 + tkutils 0.41.0.

## 0.56.0

Adds one console module; the library remains pure Tcl and runs on Tcl 8.6 and
Tcl 9.x.

- Terminal / console: `tuterm` -- ANSI terminal styling (SGR): text attributes
  and 16- / 256- / 24-bit colors via `style` / `wrap`, an SGR `strip`, a global
  `enable` switch that honours the `NO_COLOR` convention (`auto`), and optional
  Windows VT-mode init (`enableVT`, via `twapi`; no-op on other platforms).
  Generalised from a console helper; GUI-free. Ships with `test`, `doc`, `man`
  and demo. Added to the umbrella (now 0.56.0).
- Recommended pairing: tclutils 0.56.0 + tkutils 0.41.0.

## 0.55.0

Adds two number modules; the library remains pure Tcl and runs on Tcl 8.6 and
Tcl 9.x.

- Numbers: `tunum` -- locale-aware parsing of grouped / currency amounts
  (EU `1.234,56`, US `1,234.56`, currency-symbol stripping) with `parse`,
  `sum` (skips non-numeric values) and `isNumber`. Pure Tcl, value-based;
  output is always a Tcl number.
- Numbers: `tunumany` -- a single `parse` entry point that routes to the right
  backend instead of merging them: locale / currency strings go to `tunum`,
  SI/IEC unit notation (`1.5K`, `2Mi`) to `tunumfmt`, with `-prefer` to force a
  route and a fallback to the other. Keeps the two specialised parsers separate
  while giving callers one function for either notation.
- `tunum` and `tunumany` are added to the umbrella; each ships with `test`,
  `doc`, `man` and demo. `tcltest` suite green on Tcl 8.6 and Tcl 9.x.
- Recommended pairing: tclutils 0.55.0 + tkutils 0.41.0.

## 0.54.0

Adds one module; the library remains pure Tcl and runs on Tcl 8.6 and Tcl 9.x.

- Deployment / packaging: `tudeploy` -- runtime discovery and loading of Tcl
  module packages from application-relative deployment roots (`vendor`,
  `libs/common`, `libs`, `lib/tm`), plus locating bundled resource
  directories for external binaries. Generalises the recurring "add candidate
  roots to `tcl::tm::path`, then `package require`" idiom; pairs with
  `tuexe` for decoder/tool lookup. Includes `test`, `doc`, `man`, and demo.
- Introspection / diagnostics: `tupkgfinder` -- inspect package resolution
  (known versions, `ifneeded` scripts and source paths, active vs. shadowed
  version, search paths, optional filesystem search); and `tuappinfo` --
  collect a plain-text application/system report (Tcl/Tk, environment, search
  paths, loaded packages, tracked modules) with optional anonymisation. Both
  pure Tcl and GUI-free; rendering is left to the caller. Each ships with
  `test`, `doc`, `man`, and demo.
- Recommended pairing: tclutils 0.54.0 + tkutils 0.40.0.

## 0.53.0

Changes since 0.41.0. Many modules were added; the library remains pure Tcl
(Tcl core only; `zlib` optional for ZIP) and runs on Tcl 8.6 and Tcl 9.x.

- PNG / image family: `tupng` (PNG read/write), `tupngdraw` (canvas-style
  drawing to PNG), `tupngpad`, `tucodepng`, `tutablepng`, `tumonthpng`,
  `tusvg` (SVG generation), and `tuimage` (image type/dimension/data-URI
  helpers).
- Date / web / IDs: `tudate`, `tuurl`, `tuuuid`, `tudav` (WebDAV client),
  `tufetch` (tiny HTTP(S) `get`/`download`, native `http`+`tls` else
  curl/wget), and `tusparql` (thin SPARQL client). The net helpers are
  optional and not dependency-free.
- Events / logging / registry: `tuevent`, `tulog`, `turegistry`.
- Calendar / recurrence: `turrule` (RRULE expansion), `tuholiday`.
- Strings / validation: `tustr`, `tuvalidate`, `tupagespec` (page-range
  spec parser, e.g. `1-3,5,7-`).
- Lists / dicts / math / tables: `tulist`, `tudict`, `tumath`, `tutable`.
- Stream / filesystem: `tuopen` (open files/URLs with the OS handler) and
  `tuexe` (locate external executables across bundled dirs and PATH).
- Data / records: `tusqlite` (TDBC/sqlite helper, optional), `tubookmark`.
- Text filters / encoding: `tucsplit`, `tufmt`, `tubase32`.
- Module hygiene: per-module `test` / `doc` / `man` across all 96 umbrella
  modules; `tcltest` suite green on Tcl 8.6 and Tcl 9.x.
- Recommended pairing: tclutils 0.53.0 + tkutils 0.40.0.

## 0.41.0

Initial public release.

- Pure-Tcl utility library, no external dependencies (Tcl core only; `zlib`
  optional for ZIP). Runs on Tcl 8.6 and Tcl 9.x.
- Coreutils-style text filters (cat, tac, rev, nl, seq, head, tail, wc, sort,
  tsort, uniq, cut, paste, join, comm, split, fold, expand, shuf, column, pr,
  tr, sed-subset, grep, awk, xargs).
- Compare/patch: `tucmp`, `tudiff`, `tupatch`.
- Binary / encoding / checksums: `tubin`, `tuhexdump`, `tuod`, `tuhexedit`,
  `tubase64`, `tucrc`, `tustrings`, `tuiconv`, `tucode`, and `tuhash`
  (SHA-256 / SHA-1 / MD5, verified against the standard vectors).
- Data / serialization: `tucsv` (RFC-4180 quoting, multiline, BOM strip,
  lenient `-strict 0`), `tujson` (parse / `parseTyped` / `fromJson` and the
  `toJson` encoder with builders), `tuxml`, `tunumfmt`.
- Stream / filesystem: `tufile`, `tufind`, `tustat`, `tutee`, `tupath`
  (normalize/clean/relative/commonPath/readlink), `tusize` (du-like).
- Fuzzy search: `tufuzzy`, `tuagrep`.
- Records / PIM (read + edit): `tunotes`, `tuical`, `tuini`, `tuvcard`,
  `tuldif`.
- Document helpers: `tumd`, `tupdf`, `tuodf`, `tucal`.
- Archive: `tuzip`, `tuzipfs`.
- Thin CLI wrappers in `bin/` and runnable demos in `examples/`.
- Full `tcltest` suite, green on Tcl 8.6 and Tcl 9.x.
