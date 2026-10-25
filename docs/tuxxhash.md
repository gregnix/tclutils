# tclutils::tuxxhash

xxHash32 (XXH32) in pure Tcl, Tk-free. A **fast, non-cryptographic** hash for
content de-duplication and change detection — not for security. The pure-Tcl
implementation provides the 32-bit variant and matches the reference xxHash32
bit for bit (verified against the canonical vectors and python-xxhash).

Pure Tcl, 8.6+ / 9.x. No dependencies.

## Commands

```tcl
tuxxhash::xxh32     data ?seed? ?-encoding utf-8|binary?   ;# -> 8 hex chars
tuxxhash::xxh32file path ?seed?                        ;# -> 8 hex chars
```

Like `tclutils::tuhash`: digests of text are UTF-8, files hash their bytes.
`xxh32` encodes `data` to UTF-8 before hashing (`-encoding utf-8`, the
default), so `xxh32 "Größe"` is the hash of the 7 bytes `47 72 c3 b6 c3 9f 65`
and equals `xxh32file` of a UTF-8 file with that text. `-encoding binary` takes
`data` as raw bytes (each character 0–255) — use it for a binary string, e.g.
from `binary format` or a channel in `-translation binary`. `xxh32file` always
hashes the file's bytes. `seed` is an optional 32-bit integer (default 0); it
comes before `-encoding`.

## Example

```tcl
package require tclutils::tuxxhash 0.2
namespace import ::tclutils::tuxxhash::*

xxh32 "The quick brown fox jumps over the lazy dog"   ;# -> e85ea4de
xxh32 "" 0                                            ;# -> 02cc5d05
xxh32 "Größe"                                         ;# -> 3a44ca22
xxh32 [binary format c* {0 1 2}] 0 -encoding binary   ;# raw bytes
xxh32file /share/2026/rechnung.pdf                    ;# content fingerprint
```

De-duplication in a scanner: a cheap `xxh32file` groups candidates; compare the
full bytes (or a strong hash) only within a colliding group.

## xxh32 vs. sha256

`xxh32` is much faster but **not** collision-resistant against an adversary and
is only 32 bits wide, so accidental collisions appear in large corpora. Use it
to *detect change* and to *bucket* likely duplicates; use `sha256` (tcllib) when
you need a cryptographic guarantee or a wide digest. The 64/128-bit xxHash
variants are not available in pure Tcl — they need the native extension.

## Errors

Error code `{TCLUTILS TUXXHASH <REASON>}`:

| REASON | When |
|--------|------|
| `SEED` | seed is not an integer |
| `OPTION` | an argument other than `-encoding`, or too many arguments |
| `ENCODING` | `-encoding` is neither `utf-8` nor `binary` |
| `BYTES` | `-encoding binary` with a character above 255 |
| `IO` | `xxh32file` could not open the file |

## Testing

`tests/tuxxhash.test` checks the output against reference vectors (empty, short,
16-byte block boundary, long, seeded, binary bytes), UTF-8 text against the
same bytes with `-encoding binary`, and the file path. Set
`TCLUTILS_TM` to the module directory and run with `tclsh` (passes on 8.6 and
9.0).
