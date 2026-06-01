# tclutils module status

This document summarizes the declared scope of the modules. A partial module is
not necessarily incomplete; many modules are intentionally small Tcl helpers, not
full GNU or format-standard replacements.

## Text and coreutils-like modules

| Module | Scope status | Notes |
|---|---|---|
| `tugrep` | subset | Line-oriented regexp/fixed grep with context (-A/-B/-C); no multiline, PCRE, or recursive traversal by itself. |
| `tuagrep` | extension | Approximate grep using `tufuzzy`; useful but more expensive than exact grep. |
| `tused` | subset | Replace/delete/process mini-sed; no hold space, branching, or complete sed script syntax. |
| `tufind` | subset | Portable file discovery; no full find expression language. |
| `tuwc` | basis complete | Lines, words, chars, bytes. |
| `tucat` | subset | Basic cat with numbering helpers. |
| `tuhead` / `tutail` | subset | Line-based; no byte mode or follow mode. |
| `tusort` | subset | Built on Tcl `lsort`; no external large-file sort. |
| `tuuniq` | basis complete | Adjacent unique and counts. |
| `tucut` | subset | Field mode; no byte/character cut mode yet. |
| `tupaste` | basis complete | Basic paste-style line joining. |
| `tujoin` | subset | Inner join; no outer join options yet. |
| `tusplit` / `tucsplit` | basis complete | Line/byte split and regexp/glob csplit helpers. |
| `tucomm` | basis complete | Three-way comparison of sorted line sets. |
| `tufold` | basis complete | Width-based folding for text. |
| `tutr` | subset | Translate/delete/squeeze helpers; no POSIX character classes yet. |

## Compare and patch

| Module | Scope status | Notes |
|---|---|---|
| `tucmp` | basis complete | Byte-wise equality and first difference. |
| `tudiff` | subset | Line LCS, unified/context, directory diff; no streaming binary diff. |
| `tupatch` | subset | Unified diff apply, reverse, strict, multi-hunk; no three-way merge. |

## Archive and binary

| Module | Scope status | Notes |
|---|---|---|
| `tuzip` | subset | Small ZIP/ODF-friendly create/read/extract; no Zip64, password, or streaming. |
| `tuzipfs` | platform-limited | Tcl 9 ZipFS wrapper; Tcl 8.6 reports unavailable for ZipFS operations. |
| `tubin` | basis complete | Binary primitive helpers used by other modules. |
| `tuhexdump` / `tuod` | subset | Practical dump helpers; not full hexdump/od format language. |
| `tuhexedit` | helper | Read/write/search/patch/dump helpers; GUI is separate future work. |
| `tustrings` | basis complete | ASCII string extraction from binary data. |
| `tuiconv` | subset | Tcl encoding conversion helper; not full iconv clone. |
| `tubase64` / `tucrc` | basis complete | Thin wrappers over Tcl core binary/zlib facilities. |
| `tuhash` | basis complete | Pure-Tcl SHA-256, SHA-1, MD5 (string and file); verified against standard vectors. |

## Data, stream, and filesystem

| Module | Scope status | Notes |
|---|---|---|
| `tucsv` | basis complete | CSV parse/join with quoting and multiline handling. |
| `tujson` | helper + parser + encoder | Escape, quote, pretty, minify, validate, `parse`/`fromJson`/`parseTyped`, and `toJson` (typed value -> JSON, with `str`/`num`/`bool`/`null`/`obj`/`arr` builders). |
| `tuxml` | helper | Escape and tag builder; no DOM/XPath. |
| `tupath` | basis complete | Path helpers: normalize, lexical clean, relative, commonPath, readlink. |
| `tusize` | basis complete | Recursive byte sizes and human-readable formatting (du-like). |
| `tutee` | subset | Tee-like write/copy helpers; no process pipeline management. |
| `tuxargs` | subset | Batch command-prefix application; no parallel mode or `-0`. |
| `tustat` | subset | `file stat` dict and render helper; not full stat(1). |

## Fuzzy and document helpers

| Module | Scope status | Notes |
|---|---|---|
| `tufuzzy` | extension | Edit distance, approximate substring distance, similarity, subsequence, best match. |
| `tuagrep` | extension | Approximate line grep on top of `tufuzzy`. |
| `tuodf` | minimal document helper | Create/read simple ODT text documents; not a full ODF library. |
| `tupdf` | inspector | Read-only PDF structure scan plus ZUGFeRD/Factur-X heuristics; not a full PDF parser or PDF/A-3/EN 16931 conformance check. |
| `tumd` | Markdown helper | CommonMark subset to HTML, headings, TOC, frontmatter; not a full Markdown engine. |
| `tufile` | inspector | Magic-signature file type detection with user-extensible table and extension-mismatch check; offset+exact-bytes model, not libmagic. |
| `tuawk` | processor | awk-style record/field processing; Tcl expr patterns and Tcl actions, BEGIN/END, emit. Not an awk-language interpreter. |
| `tucal` | generator | cal-like calendars (month/year/three-month, ISO weeks, locale names). Text output only, not a scheduling library. |
| `tucode` | reference | Character-code tables for bytes 0..255 (ASCII, Latin-1/ANSI, sign groups, lookup). Byte-oriented, not a full Unicode chart. |
| `tunl` | filter | `nl`-like line numbering (all/nonempty/none styles, start, increment, width, separator). Preserves trailing newline. |
| `tuseq` | generator | `seq`-like numeric sequences (last / first last / first incr last), float steps, `-format`, `-equalwidth`. |
| `turev` | filter | `rev`-like reversal of characters within each line (Unicode by code point). |
| `tutac` | filter | `tac`-like reversal of line order. Preserves trailing newline. |
| `tuexpand` | filter | `expand`/`unexpand` between tabs and spaces with correct tab-stop alignment. |
| `tushuf` | filter | `shuf`-like line shuffling with a seedable, platform-independent PRNG and `-count`. |
| `tucolumn` | filter | `column`-like columnation: table mode (align delimited columns) and fill mode (column-major). |
| `tupr` | filter | `pr`-like page formatting with a date/title/page header and optional line numbering. |
| `tutsort` | algorithm | `tsort`-like topological sort of token pairs; stable first-seen order; detects cycles and odd input. |
| `tunumfmt` | filter | `numfmt`-like human-readable number formatting (SI/IEC) and parsing back; line-wise text mode. |

## Highest-priority improvements

1. Synchronize test corpora for `tuodf`, `tupdf`, `tumd`, `tufuzzy`, and `tuagrep`.
3. Add `tugrep` context output and `tused` address support.
4. Add broader CLI tests as CLI wrappers grow.
5. Continue documenting scope boundaries explicitly per module.
