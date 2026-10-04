# Changelog

## 0.64.0

Recommended pairing: tclutils 0.64.0 + tkutils 0.46.0 + ctrlutils 0.3.

- `tustr` 0.2: `graphemes` (user-perceived characters, simplified UAX #29)
  and `isPrintable` (Unicode, not only ASCII). Surrogate pairs from Tcl 8.6
  count as one character.
- `tudate` 0.2: `zones` lists the time zones `clock` accepts.
- `tusettings` 0.1 (new): per-user settings as INI in the platform's config
  directory, `dir config|cache|data|temp`, recent-files list.
- `tutestrun` 0.1 (new): the shared `tests/all.tcl` (own trees first, banner,
  per-file limit, summary). tclutils, tkutils and ctrlutils use it; the
  tclutils runner now passes tcltest options and lists problem files.
- `tunum` 0.4: `format` rounds half away from zero on every platform
  (`1234.5 -decimals 0` is `1.235`); `format %.*f` rounded differently on
  Windows.
- `tupath::clean`: an absolute path keeps its root (`C:/` on Windows), `..`
  stops there.
- Tests run on Windows: no `/dev/null` or Unix roots in fixtures, `cli-1.10`
  copies binary; `tuhttps`/`tufetch` tests that need a CA bundle are skipped
  without one (constraint `caOK`). The TLS tests in `tufetch.test` are
  renumbered 4.x (3.x was used twice).
- `tutestrun`: output a test file writes in another encoding no longer stalls
  the run under Tcl 9 (the file ran into the limit); such bytes are replaced.
- `tupkgfinder` 0.2: `candidates` and `shadows` list every copy of a package
  on the module paths and `auto_path`, including a second copy with the same
  version, which the package database does not show.

## 0.63.0

Security and robustness release. Recommended pairing: tclutils 0.63.0 +
tkutils 0.46.0 + ctrlutils 0.3.

### Tests / runner (2026-10-03)

- `tupostgrest.test` pg-1.1: umlaut via `\u00fc` in `[list …]` so Tcl 8.6 with
  iso8859-1 / cp1252 script encoding does not double-encode the URL.
- `tests/all.tcl`: per-file wall-clock limit (`TCLUTILS_TESTGRENZE`, default 120 s).

### `tuflow`: hyphen in a node id is `BADID` (2026-09-24)

Node ids stay `[A-Za-z0-9_]+`. A leftover `-3` after an id (e.g.
`Nwifi-3["SSID"]`) used to be swallowed: the graph kept `Nwifi` and dropped
the rest, with no error. `parse` now raises `{TCLUTILS TUFLOW BADID}` and
names the id plus the allowed alphabet. Underscore ids (`Nwifi_3`) are
unchanged. Package remains `tclutils::tuflow` 0.2.

### Caps contract (2026-09-23)

`docs/tuprovider.md` holds one table of `caps` per scheme (local / zip / dav /
ftp / sftp). `tests/tuprovider-caps.test` reads that table. SFTP `head` stays
the base default (full `get`, then truncate): OpenSSH `sftp get [-afpR]` has
no byte range.

### The test runner says where the modules come from

Before the tests run, `tests/all.tcl` prints which file each library
(tclutils) resolves to -- found without loading anything -- and which
module-path variables are set; an old file beside a new one shows as
`(also: <version>)`. (Idea 5 of ideen-tclutils-tkutils.md.)

Own trees first: when the tree is already listed in `TCL8_6_TM_PATH` /
`TCL9_0_TM_PATH` behind a directory with an installed copy of the same version
(e.g. `site-tcl`), `tcl::tm::path add` does nothing and the installed copy
wins -- the suite then tests that copy, not the tree (reproduced with Tcl 8.6:
`TCL8_6_TM_PATH=<tree>:<site-tcl>`). The runner now removes its own trees from
those variables for the test processes and puts them in front in its own
interpreter, so the banner shows what the tests load. A test file started
directly, without the runner, is still exposed to this.

### `common::ensureOneOf` (in `common` 0.2)

`ensureOneOf value allowed what` returns the value or raises
`unknown <what>: <value>` / `Known: ...` with `{TCLUTILS COMMON VALUE <what>}`
-- the enum counterpart to `parseOptions` (idea 2). `common` was already
counted up to 0.2 in this release.

### Security: HTTPS certificates are verified again — and the check stays local

Measured 2026-09-19 against a local self-signed server: after **one**
`tufetch` call, every later `::http::geturl https://…` in the process accepted
the forged certificate. `::http::register` is global to the interpreter, and
three modules each registered `https` with their own policy and never undid it:

| module | registered | verified? |
|---|---|---|
| `tufetch` 0.3 | on every call | no (`-require 0`) |
| `tupostgrest` 0.1 | on every request | yes, unless `-insecure 1` |
| `tudav` 0.1 | once, for good | tls 2.0 yes; **tls 1.x (Tcl 8.6) never** |

- **`tuhttps` 0.1 (new)** — one place for the rule. `socketCmd` builds a
  verifying `::tls::socket` prefix (`-insecure 1` is the only way to switch the
  check off; `-cafile` for an internal CA; no SNI for IP literals). `with`
  registers `https` only for the duration of a script and restores the previous
  registration afterwards, also on error. tls 1.x does not find the system CA
  store by itself; `socketCmd` then looks for a CA bundle (`SSL_CERT_FILE`, the
  usual Linux/BSD/macOS paths) and raises `NOCA` with the way out if there is
  none — it never falls back to "unverified".
- **`tufetch` 0.4** — verifies on all three transports; `-insecure 0|1` and
  `-cafile` now apply to native, curl (`-k`/`--cacert`) and wget
  (`--no-check-certificate`/`--ca-certificate`) alike. A `CONNECT` error on
  https names `-cafile`/`-insecure`. tls 1.x without a CA bundle: the native
  path steps aside for curl/wget; with neither, `NOMETHOD` names the way out.
  New errorcode `{TCLUTILS TUFETCH CAFILE}`.
  Also fixed: the wget fallback passed each header as two arguments
  (`--header=Name:` and the value), so wget took the value for a second URL.
  The old test matched the joined list as a string and stayed green.
- **`tudav` 0.2** — client and `configure` take `-cafile` and `-insecure`;
  https is registered per request. `configure` lists the known options on an
  unknown one.
- **`tupostgrest` 0.2** — `-cafile` added; `-insecure` now affects only that
  client's requests. `new` lists the known options on an unknown one and checks
  that `-insecure` is a boolean.
- `tuprovider::dav` passes `-cafile`/`-insecure` through to `tudav`.

**Behaviour change.** Code that relied on a self-signed or internal certificate
being accepted silently now gets an error that suggests `-cafile` (preferred)
or `-insecure 1`. On Tcl 8.6 with tls 1.x and no CA bundle (typical on
Windows), `tudav` and `tupostgrest` fail with the way out in the message, and
`tufetch` uses curl/wget or fails with `NOMETHOD`. Not measured: tls 2.0 on
Windows; if its OpenSSL build finds no CA store the handshake fails loudly and
`-cafile` is the way out.

Tests run offline: `tests/data/https-server.tcl` serves a self-signed
certificate (`tests/data/tuhttps-localhost.crt`, test use only) from a child
process — in the test's own interpreter the blocking tls handshake hung. Each
new test was run against the previous module version first: `tufetch` 10,
`tudav` 5 (under 8.6 the old `tudav` accepted the forged certificate),
`tupostgrest` 4 failures.

### The umbrella loads without tcllib again (`tuprovider::ftp` 0.2)

`tuprovider::ftp` did `package require ftp` (tcllib) when it was loaded, and
the umbrella loads it — so `package require tclutils` failed on every system
without tcllib, against CONTRIBUTING rule 1. Found 2026-09-19 because
tkutils' `stack.test` exited 1 under Tcl 8.6 (no tcllib in that environment);
under 9.0 tcllib was installed and nothing showed. The tcllib client is now
loaded when a connection is opened; without it, `open ftp …` fails with
`{TCLUTILS TUPROVIDER FTP NOPKG}` and says what is missing. A new test checks
in a fresh process that loading the provider does not load `ftp`; against 0.1
it fails, with or without tcllib installed.

### Every module has a description and a category

8 modules had neither a `# Description:` nor a `# Category:` header line, so
`tools/check-modules.tcl` and its GUI showed empty columns for them (the storage providers, `tuico`, `tudhash`, `tuxxhash`).
Added, with categories from the existing list. `tests/headers.test` (new)
fails when a module lacks either line (counter-checked by removing one).

### `tools/md2man.tcl`: sub-modules

`md2man.tcl` converts only docs that belong to a module, and looked for the
module as `lib/tm/<repo>/<mod>-X.Y.tm` only. The docs of sub-modules
(`docs/tuprovider-ftp.md` for `lib/tm/tclutils/tuprovider/ftp-0.2.tm`) counted
as "no module" and were skipped without a word — hence the missing man pages
for `tuprovider-ftp` and `tuprovider-sftp` (and stale ones for `-dav`/`-zip`),
the same gap `check-modules.tcl` had. It now also tries
`lib/tm/<repo>/<parent>/<child>-X.Y.tm`. Measured into a scratch directory:
136 pages before, 140 after, `tuprovider-ftp.n` with `.TH … 0.2`.

### `tools/check-modules.tcl`: sub-modules

For modules in a sub-directory (`lib/tm/tclutils/tuprovider/dav-0.1.tm`) the
manifest rebuilt the path as `lib/tm/tclutils/tuprovider-dav-0.1.tm`, which
does not exist. Description, category and dependencies of the four provider
backends therefore came out empty — also after the header lines were added —,
the path column was wrong, and the package column said
`tclutils::tuprovider-dav` instead of `tclutils::tuprovider::dav`. The GUI
opens the module from that path, so a click on such a row pointed at a missing
file. The tool now keeps the real file and package name of every module. The
human report is unchanged; in the manifest only the four provider rows change.
Checked: every manifest path in tclutils, tkutils and ctrlutils exists, and
the GUI shows the category of all five providers and opens
`tuprovider/dav-0.1.tm`.

### One version per module

`tests/versions.test` (new) checks that the version in the file name, in
`package provide` and in `variable version` agree. Five modules had a stale
`variable version`: `tumonthpng` (0.3 in a 0.4 file), `tupng` (0.2 / 0.4),
`tupngdraw` (0.11 / 0.12), `tufind` (0.1.3 / 0.1), `tudiff` (0.1.2 / 0.1). They
now say what `package provide` says. Nothing reads the variable. The test does
not look for old files lying next to new ones; `tools/check-modules.tcl`
reports those as multi-version.

### Documentation

`docs/guide/architecture.md` knows the storage providers (new section, with
the model/view/controller split of the Explorer stack), `tuhttps`,
`tupostgrest`, `tutdbc` and the hash modules `tudhash`/`tuxxhash`.

### `common` 0.2

- `parseOptions` names the known options on an unknown one:
  `unknown option "-typ"` / `Known: -type -timeout`. The errorcode is
  unchanged (`{TCLUTILS COMMON OPTION <opt>}`); no existing test compared the
  full message. Every module that uses `parseOptions` gets the new message.
- `readFile` and `writeFile` take `-encoding enc`. Without it they keep using
  the system encoding (utf-8 on Linux, usually cp1252 under Tcl 8.6 on
  Windows) — pass `-encoding utf-8` where non-ASCII text is compared.

### Tests independent of the environment

`tudhash.test` and `tuxxhash.test` found their module only through
`TCLUTILS_TM`; under a plain `tclsh tests/all.tcl` they aborted without a
summary. They now add `lib/tm` themselves, like the other test files.

Measured 2026-09-19 without any module path in the environment (145 test
files, each with a summary): Tcl 9.0.4 / tls 2.0 — 1819 passed, 12 skipped;
Tcl 8.6.14 / tls 1.7.22, no tcllib — 1758 passed, 73 skipped; 0 failed on
both, `all.tcl` exit 0.

## 0.62.0

### Added

- **`tunotesdb` 0.1** — the persistent counterpart to `tunotes`: one row per
  note in SQLite instead of one Tcl dict saved as JSON.
  - Same note layout (`id parent_id title content created modified tags`) and
    the same timestamp format, so both engines are interchangeable and
    `tkutils::tkunotes` works with either.
  - The hierarchy lives in `parent_id` and is queried with `WITH RECURSIVE`:
    `descendants`, `ancestors`, `path`, `depth`, `siblings` and `subtree` do
    their work in the database rather than loading every note to follow a chain
    of parents.
  - **Full-text search through FTS5** with ranking and snippets, as an
    external-content index (`content='notes'`) kept in step by three triggers —
    the text is not stored twice and no application code has to reindex. A
    syntactically wrong query raises `BADQUERY` instead of looking like an empty
    result.
  - `init` is idempotent and switches the database to WAL, so readers do not
    block the writer.
  - Bridges both ways: `toStore` returns a `tunotes` store (and thus a JSON
    export via `tunotes::toJson`), `fromStore` imports one in a single
    transaction.
  - Builds on `tusqlite` for the SQL layer and, like that module, does **not**
    `package require sqlite3` itself — the caller opens the database and passes
    the handle.
  - Errors use `errorCode {TCLUTILS TUNOTESDB <REASON>}`.
  - 41 tests, green on Tcl 8.6 (SQLite 3.45) and 9.0 (SQLite 3.53); without the
    `sqlite3` package they are skipped, not failed.

`tunotes` remains the right choice for a handful of notes and for anywhere that
must stay free of external packages. `tunotesdb` is for many notes, several
writers, or a server.

## 0.61.0

Adds a Windows icon container, pure Tcl and without Tk, as the writing
counterpart to tklib's `ico` package.

- `tuico` 0.1 — the `.ico` container format. `write` builds a file from
  `{size pngData}` pairs and validates every payload first (PNG signature, IHDR
  dimensions against the declared size), so a rejected call leaves no partial
  file behind. `info` reports each entry as a dict (`width`, `height`, `bpp`,
  `format`, `offset`, `length`) and recognises BMP payloads on read; `extract`
  returns a payload, optionally to a file.
- The entries carry **PNG payloads**, which Windows accepts since Vista and
  which keep an alpha channel. This is the gap tklib's `ico` leaves open: it
  reads icons from ICO/EXE/DLL/ICL, but by its own documentation cannot write a
  true 32bpp alpha icon from a Tk image. Use tklib `ico` to extract, `tuico` to
  write.
- Errors use `errorCode {TCLUTILS TUICO <REASON>}`.
- 15 tests, headless, green on Tcl 8.6.14 and 9.0.4.

Recommended pairing: tclutils 0.61.0 + tkutils 0.43.0 (`tkutils::tkuwinico` renders
the icon sizes and hands the PNG payloads to this module).

## 0.60.0

Adds a standalone-application builder for Tcl 9 (zipkits) and the `zipfs` image
primitives it uses. The runtime library stays pure Tcl on 8.6 and 9.x; the
builder targets Tcl 9 (zipfs is a Tcl 9 core feature).

- `tuzipfs` 0.2 — zipfs image primitives: `rcopy` (byte-exact recursive copy that
  also works from a mounted zipfs, where `file copy` is unreliable), `copyStdlib`
  (place `tcl_library` and, for GUI apps, `tk_library` into a VFS tree), `mkimg`
  (a checked wrapper over `zipfs mkimg`), and `buildImage` (drop the stdlib into
  an assembled tree and build in one call). The mount/read commands from 0.1 are
  unchanged.
- New app `build-app` — turns an app under `apps/` (tclutils or tkutils) into a
  single standalone executable, a Tcl 9 zipkit. A dependency prober runs the app
  once in the target basekit and bundles only the packages actually loaded; `-tm`
  supplies module trees, `-extlib` the roots for external pkgIndex packages
  (sqlite3, tdbc, tablelist …), `-include SRC=DEST` copies shared code an app
  sources from a sibling directory, and `-launch` names the GUI entry proc. The
  output platform is chosen by the target `-basekit`, so the same builder makes
  Linux and Windows binaries; the standard library is taken from that basekit.
- Self-hosting builder — `build-app` is also shipped as
  `apps/bin/build-app-zipkit-linux`, a zipkit that carries `tuzipfs` embedded, so
  a build host needs only that file plus the basekits (no installed Tcl or
  tclutils).
- Reproducible builds — `-writemanifest FILE` records the prober's dependency
  closure as an editable list; `-manifest FILE` builds from that list without
  probing (no display needed), for CI or for shipping an app as scripts plus a
  package list. Native client libraries (libpq, the Oracle client) are not Tcl
  packages and remain a target-system dependency either way.
- Docs — `docs/guide/build-app-guide.md` (with a pipeline diagram),
  `docs/guide/build-app-app-conventions.md`, `apps/build-app/README.md` and the
  worked `EXAMPLE-*` tutorials, `apps/_template/` skeletons (GUI + CLI). The
  `tuzipfs` man page and doc are updated to 0.2.
- Recommended pairing: tclutils 0.60.0 + tkutils 0.42.2.

## 0.59.0

- Fixed the umbrella typo `tclutis::tulayout` in `tclutils-0.58.0.tm`, which
  broke `package require tclutils` entirely (the umbrella now loads).
- Umbrella now also loads `tuxxhash`, `tudhash` and `tupostgrest`.
- Added man pages for `tudhash` and `tuxxhash`.
- Recommended pairing: tclutils 0.59.0 + tkutils 0.42.0.
- tupdf 0.2

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
