# tclutils module status

This document summarizes the declared scope of the modules. A partial module is
not necessarily incomplete; many modules are intentionally small Tcl helpers, not
full GNU or format-standard replacements.

The grouping matches the top-level `README.md`. A module that the README lists in
two categories (`tuical`, `tucal`) appears in both here as well.

## Text / coreutils filters

| Module | Scope status | Notes |
|---|---|---|
| `tucat` | subset | Basic cat with numbering helpers. |
| `tutac` | filter | `tac`-like reversal of line order. Preserves trailing newline. |
| `turev` | filter | `rev`-like reversal of characters within each line (Unicode by code point). |
| `tunl` | filter | `nl`-like line numbering (all/nonempty/none styles, start, increment, width, separator). Preserves trailing newline. |
| `tuseq` | generator | `seq`-like numeric sequences (last / first last / first incr last), float steps, `-format`, `-equalwidth`. |
| `tuhead` / `tutail` | subset | Line-based; no byte mode or follow mode. |
| `tuwc` | basis complete | Lines, words, chars, bytes. |
| `tusort` | subset | Built on Tcl `lsort`; no external large-file sort. |
| `tutsort` | algorithm | `tsort`-like topological sort of token pairs; stable first-seen order; detects cycles and odd input. |
| `tuuniq` | basis complete | Adjacent unique and counts. |
| `tucut` | subset | Field mode; no byte/character cut mode yet. |
| `tupaste` | basis complete | Basic paste-style line joining. |
| `tujoin` | subset | Inner join; no outer join options yet. |
| `tucomm` | basis complete | Three-way comparison of sorted line sets. |
| `tusplit` / `tucsplit` | basis complete | Line/byte split and regexp/glob csplit helpers. |
| `tufold` | basis complete | Width-based folding for text. |
| `tuexpand` | filter | `expand`/`unexpand` between tabs and spaces with correct tab-stop alignment. |
| `tushuf` | filter | `shuf`-like line shuffling with a seedable, platform-independent PRNG and `-count`. |
| `tucolumn` | filter | `column`-like columnation: table mode (align delimited columns) and fill mode (column-major). |
| `tupr` | filter | `pr`-like page formatting with a date/title/page header and optional line numbering. |
| `tutr` | subset | Translate/delete/squeeze helpers; no POSIX character classes yet. |
| `tused` | subset | Replace/delete/process mini-sed; no hold space, branching, or complete sed script syntax. |
| `tugrep` | subset | Line-oriented regexp/fixed grep with context (-A/-B/-C); no multiline, PCRE, or recursive traversal by itself. |
| `tuawk` | processor | awk-style record/field processing; Tcl expr patterns and Tcl actions, BEGIN/END, emit. Not an awk-language interpreter. |
| `tuxargs` | subset | Batch command-prefix application; no parallel mode or `-0`. |
| `tufmt` | filter | `fmt`-like paragraph reflow to a width; collapses whitespace, keeps per-paragraph indent. |

## Compare / patch

| Module | Scope status | Notes |
|---|---|---|
| `tucmp` | basis complete | Byte-wise equality and first difference. |
| `tudiff` | subset | Line LCS, unified/context, directory diff; no streaming binary diff. |
| `tupatch` | subset | Unified diff apply, reverse, strict, multi-hunk; no three-way merge. |

## Binary / encoding / checksums

| Module | Scope status | Notes |
|---|---|---|
| `tubin` | basis complete | Binary primitive helpers used by other modules. |
| `tuhexdump` / `tuod` | subset | Practical dump helpers; not full hexdump/od format language. |
| `tuhexedit` | helper | Read/write/search/patch/dump helpers; GUI is separate future work. |
| `tubase64` / `tucrc` | basis complete | Thin wrappers over Tcl core binary/zlib facilities. |
| `tuhash` | basis complete | Pure-Tcl SHA-256, SHA-1, MD5 (string and file); verified against standard vectors. |
| `tustrings` | basis complete | ASCII string extraction from binary data. |
| `tuiconv` | subset | Tcl encoding conversion helper; not full iconv clone. |
| `tucode` | reference | Character-code tables for bytes 0..255 (ASCII, Latin-1/ANSI, sign groups, lookup). Byte-oriented, not a full Unicode chart. |
| `tubase32` | basis complete | RFC 4648 base32 and base32hex encode/decode (pure Tcl; core has only base64). |
| `tuimage` | basis complete | Detect format/MIME/dimensions from image bytes + data: URIs; pure-Tcl. |
| `tupng` | basis complete | Pure-Tcl PNG encoder (indexed/RGB/RGBA/gray) via core zlib; encode-side companion to `tuimage`. |
| `tupngdraw` | toolkit | Immediate-mode 2D drawing onto an RGBA buffer (lines/arrows/shapes, AA fills/strokes, bitmap font, `fillcontours`, `paste`); emits PNG via `tupng`. |
| `tutablepng` | renderer | Renders data rows to a styled PNG table; built on `tupngdraw`. |
| `tumonthpng` | renderer | Month/quarter/year calendar to PNG (monthcanvas look); themes, day states, `-textcmd`. |
| `tucodepng` | renderer | Character-code/codepage table to PNG grid; data from `tucode`. |
| `tupngpad` | tool | Normalises (transparent) PNGs to a uniform size with margin on a background (trim/pad/flatten). Pure Tcl, for sprite/icon sizes. |
| `tusvg` | generator | Pure-Tcl SVG generator: shapes/paths/text/gradients/groups to string or file, plus a library of ~110 named toolbar icons (`icon`/`icons`/`saveIcon`). No dependencies; vector counterpart to `tupng`. |
| `tulayout` | helper | Page layout helpers: millimetre coordinates and block-dict placement; shared by the PNG/SVG renderers and PDF layout. |

## Terminal / color

| Module | Scope status | Notes |
|---|---|---|
| `tucolor` | basis complete | Named-color database; resolves names / hex / rgb to RGB, converts to hex and HSV, and finds the nearest named color. |
| `tuterm` | toolkit | ANSI terminal styling (SGR): text attributes and 16/256/24-bit colors; global enable switch that honours `NO_COLOR`. |

## Data / serialization

| Module | Scope status | Notes |
|---|---|---|
| `tucsv` | basis complete | CSV parse/join with quoting and multiline handling. |
| `tujson` | helper + parser + encoder | Escape, quote, pretty, minify, validate, `parse`/`fromJson`/`parseTyped`, and `toJson` (typed value -> JSON, with `str`/`num`/`bool`/`null`/`obj`/`arr` builders). |
| `tuxml` | helper | Escape and tag builder; no DOM/XPath. |
| `tusqlite` | helper | NULL-safe helpers over a caller-supplied `sqlite3` handle: `insert` (omitted key or `null` → SQL NULL), `rows` → list of dicts, `value`, `quoteId`. Does not `require sqlite3` itself. |
| `tummdb` | reader | Pure-Tcl reader for MaxMind DB (`.mmdb`) binary geolocation databases. |

## Stream / filesystem

| Module | Scope status | Notes |
|---|---|---|
| `tufile` | inspector | Magic-signature file type detection with user-extensible table and extension-mismatch check; offset+exact-bytes model, not libmagic. |
| `tufind` | subset | Portable file discovery; no full find expression language. |
| `tustat` | subset | `file stat` dict and render helper; not full stat(1). |
| `tutee` | subset | Tee-like write/copy helpers; no process pipeline management. |
| `tupath` | basis complete | Path helpers: normalize, lexical clean, relative, commonPath, readlink. |
| `tusize` | basis complete | Recursive byte sizes and human-readable formatting (du-like). |
| `tuopen` | basis complete | Open URL/file with the OS default app (xdg-open/open/cmd start). |

## Fuzzy search

| Module | Scope status | Notes |
|---|---|---|
| `tufuzzy` | extension | Edit distance, approximate substring distance, similarity, subsequence, best match. |
| `tuagrep` | extension | Approximate grep using `tufuzzy`; useful but more expensive than exact grep. |

## Records / PIM

| Module | Scope status | Notes |
|---|---|---|
| `tunotes` | basis complete | Hierarchical note store (id/parent/title/content/tags); create/update/move/cascade-delete, `tujson` persistence. Value-based, no external packages. |
| `tuical` | basis complete | iCalendar (RFC 5545) reader/writer; component/property navigation, VEVENT helpers, 75-char folding; pairs with `turrule`. |
| `tuini` | basis complete | INI reader/writer; parses to section→(key→value) with a global section `""`, order preserved, comments dropped. |
| `tuvcard` | basis complete | vCard (RFC 6350/2426) reader/writer; 75-char folding, raw round-tripping, FN/property helpers. |
| `tuldif` | basis complete | LDIF (RFC 2849) reader/writer; base64 values via `tubase64`, automatic continuation-line unfolding. |
| `tubookmark` | basis complete | Read/write Netscape bookmark HTML (folders, tags); reuses `tuxml`. |

## Document helpers

| Module | Scope status | Notes |
|---|---|---|
| `tumd` | Markdown helper | CommonMark subset to HTML, headings, TOC, frontmatter; not a full Markdown engine. |
| `tupdf` | inspector | Read-only PDF structure scan plus ZUGFeRD/Factur-X heuristics; not a full PDF parser or PDF/A-3/EN 16931 conformance check. |
| `tuodf` | minimal document helper | Create/read simple ODT text documents; not a full ODF library. |
| `tucal` | generator | cal-like calendars (month/year/three-month, ISO weeks, locale names). Text output only, not a scheduling library. |

## Date / web / IDs

| Module | Scope status | Notes |
|---|---|---|
| `tudate` | helper | Flexible date parse/format/arithmetic on `clock`; ISO, day diff, relative phrases. Local time. |
| `tuurl` | basis complete | RFC 3986 percent-encoding/decoding and query strings (UTF-8). |
| `tuuuid` | basis complete | UUID v4 and v7 generate/validate/version; `/dev/urandom` with `rand()` fallback. |
| `tudav` | basis complete | Minimal WebDAV/CardDAV/CalDAV client (PROPFIND/REPORT/GET/PUT/DELETE, calendarQuery/addressbookMultiget); core `http`, https via `tls`. Collection provisioning (mkCalendar/mkAddressbook) added; verified vs Radicale 3.7. |
| `tuexe` | helper | Locate external executables: candidate-name list, bundled `-dirs` plus PATH (`auto_execok`), platform extensions; `find`/`all`/`exists`. |
| `tufetch` | helper | Tiny HTTP(S) `get`/`download` (to memory or file), GET/POST with headers and body; native `http`+`tls` else curl/wget via `auto_execok`. Optional, not dependency-free. |
| `tusparql` | helper | Thin SPARQL client (`query` → row dicts, `ask` → 0/1) composing `tufetch`/`tuurl`/`tujson`; GET or POST, English labels via `wikibase:label`. Optional, not dependency-free. |

## Calendar / recurrence

| Module | Scope status | Notes |
|---|---|---|
| `tuical` | basis complete | iCalendar (RFC 5545) reader/writer; component/property navigation, VEVENT helpers, 75-char folding; pairs with `turrule`. |
| `turrule` | basis complete | iCalendar RRULE expansion (FREQ/INTERVAL/COUNT/UNTIL/BYDAY/BYMONTHDAY subset); pairs with `tuical`. |
| `tuholiday` | basis complete | Easter computus + German nationwide public holidays. |
| `tucal` | generator | cal-like calendars (month/year/three-month, ISO weeks, locale names). Text output only, not a scheduling library. |

## Events / registry

| Module | Scope status | Notes |
|---|---|---|
| `tuevent` | basis complete | Publish/subscribe event bus; named bus tokens. |
| `turegistry` | basis complete | Keyed value registry / service locator with required-get. |
| `tulog` | basis complete | Small leveled logger (callable object) + assert; dependency-free. |

## Strings / validation

| Module | Scope status | Notes |
|---|---|---|
| `tustr` | helper | String helpers: case conversion (camel/snake), slugify, pad/center/truncate, prefix/suffix, splitTrim, count. |
| `tuvalidate` | helper | Format/type validation predicates: email/url/ipv4/port/alpha/alnum/length/pattern/inList. |
| `tupagespec` | helper | Parse page-range specs (`1-3,5,7-`, `all`, open ends, `end`/`last`) to a page list; `compact` is the inverse; `-base 0|1`. |

## Lists / dicts

| Module | Scope status | Notes |
|---|---|---|
| `tulist` | helper | Functional list helpers: unique/flatten/chunk/zip/sum/avg/min/max/reduce/map/filter/all/any/take/drop. |
| `tudict` | helper | Nested-dict helpers beyond core: getOr/paths/flatten/mergeDeep/invert. |

## Math / tables

| Module | Scope status | Notes |
|---|---|---|
| `tumath` | helper | Numeric helpers beyond core expr: clamp/inRange/percent/sign/gcd/lcm/factorial/roundTo. |
| `tutable` | helper | Render markdown / ASCII-box text tables from headers+rows, with alignment. |

## Number parsing / formatting

| Module | Scope status | Notes |
|---|---|---|
| `tunum` | basis complete | Locale-aware number parsing: EU `1.234,56` / US `1,234.56`, currency-symbol stripping; `parse`, `sum` (skips non-numeric), `isNumber`. Pure Tcl, value-based. |
| `tunumany` | helper | Single `parse` dispatcher: routes locale/currency strings to `tunum` and SI/IEC notation (`1.5K`, `2Mi`) to `tunumfmt`, with `-prefer` and fallback. The deliberate bridge between the two parsers (not a merge). |
| `tunumfmt` | filter | `numfmt`-like human-readable number formatting (SI/IEC) and parsing back; line-wise text mode. |

## Archive

| Module | Scope status | Notes |
|---|---|---|
| `tuzip` | subset | Small ZIP/ODF-friendly create/read/extract; no Zip64, password, or streaming. |
| `tuzipfs` | platform-limited | Tcl 9 ZipFS wrapper; Tcl 8.6 reports unavailable for ZipFS operations. |

## Deployment / packaging

| Module | Scope status | Notes |
|---|---|---|
| `tudeploy` | helper | Runtime discovery and loading of Tcl module packages from app-relative deployment roots (`vendor`, `libs/common`, `libs`, `lib/tm`), plus locating bundled resource directories for external binaries; `require` / `resourceDirs` / `sourceModule`. Pairs with `tuexe`. |

## Introspection / diagnostics

| Module | Scope status | Notes |
|---|---|---|
| `tupkgfinder` | helper | Inspect package resolution: known versions, `ifneeded` scripts and source paths, active vs. shadowed version, search paths; optional filesystem search by pattern. |
| `tuappinfo` | helper | Collect a plain-text application/system report (Tcl/Tk, environment, search paths, loaded packages, tracked modules); optional anonymisation. GUI-free; the caller renders. |

## Diagrams

Mermaid-compatible diagram rendering, pure Tcl, no browser. `tuflow` is the
facade: it detects the diagram kind from the fenced-code source and dispatches
to a parser (graph types, laid out and drawn by `tudiagram`) or to a
self-contained 2D renderer. Both paths draw through the shared `tusvg` /
`tupngdraw` canvas, so SVG and PNG output stay congruent. Consumed by
`docir::diagram` and the showcase.

| Module | Scope status | Notes |
|---|---|---|
| `tuflow` | facade | Detects the diagram language and dispatches to a parser or a 2D renderer; `parse`/`toSvg`/`toPng`. Mermaid-compatible fenced-code entry point, plus its own flowchart parser. |
| `tudiagram` | renderer | Node-edge graph renderer: layered layout, 8 node shapes, edge styles incl. `thick`, crow's-foot end-marks, themes, group/cluster frames (subgraph, since 0.4); draws to SVG or PNG via the shared canvas. |
| `tustate` | parser | Mermaid `stateDiagram(-v2)` -> tudiagram model. |
| `tuer` | parser | Mermaid `erDiagram` -> tudiagram model, with crow's-foot cardinality end-marks. |
| `tuclass` | parser | Mermaid `classDiagram` -> tudiagram model (compartments, relationship kinds). |
| `turequirement` | parser | Mermaid `requirementDiagram` -> tudiagram model. |
| `tumindmap` | parser | Mermaid `mindmap` -> tudiagram model. |
| `tuc4` | parser | Mermaid C4 (`C4Context`/`Container`/...) -> tudiagram model; boundaries flattened. |
| `tublock` | parser | Mermaid `block-beta` -> tudiagram model. |
| `tugit` | parser | Mermaid `gitGraph` -> tudiagram model. |
| `tuarchitecture` | parser | Mermaid `architecture-beta` -> tudiagram model; service/group/junction, icon->shape, group cluster frames (`in <group>`, nested). |
| `tupie` | 2D renderer | Mermaid-style `pie` chart -> SVG/PNG (own renderer, not a graph). |
| `tuxychart` | 2D renderer | Mermaid `xychart-beta` (bar/line series, axes) -> SVG/PNG. |
| `tuquadrant` | 2D renderer | Mermaid `quadrantChart` -> SVG/PNG. |
| `tujourney` | 2D renderer | Mermaid `journey` (user journey) -> SVG/PNG. |
| `tutimeline` | 2D renderer | Mermaid `timeline` -> SVG/PNG. |
| `tusankey` | 2D renderer | Mermaid `sankey-beta` flow diagram -> SVG/PNG; longest-path columns, value-proportional bands. |
| `tugantt` | 2D renderer | Mermaid `gantt` chart -> SVG/PNG; sections, tags, `after` deps, durations, milestones over a time axis. |
| `tusequence` | 2D renderer | Mermaid `sequenceDiagram` -> SVG/PNG; lifelines, all arrow types, activations, notes, autonumber, nestable loop/alt/opt/par frames. |
| `tukanban` | 2D renderer | Mermaid `kanban` board -> SVG/PNG; indent-based columns/cards, `@{...}` card metadata. |
| `tupacket` | 2D renderer | Mermaid `packet-beta` -> SVG/PNG; 32-bit rows, range/single-bit fields, gap cells. |
| `tutreemap` | 2D renderer | Mermaid `treemap-beta` -> SVG/PNG; squarified area-proportional nested rectangles, value-sum branches. |
| `turadar` | 2D renderer | Mermaid `radar-beta` -> SVG/PNG; polar spider chart, multi-axis/multi-curve, circle/polygon graticule. |

## Core

| Module | Scope status | Notes |
|---|---|---|
| `common` | shared layer | File/binary I/O, line/delimited splitting, and option parsing used by every module; not a user-facing command. |

## Highest-priority improvements

1. Synchronize test corpora for `tuodf`, `tupdf`, `tumd`, `tufuzzy`, and `tuagrep`.
2. Add `tugrep` context output and `tused` address support.
3. Add broader CLI tests as CLI wrappers grow.
4. Continue documenting scope boundaries explicitly per module.
