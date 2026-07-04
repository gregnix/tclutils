# tclutils::tuxxhash

xxHash32 (XXH32) in pure Tcl, Tk-free. A **fast, non-cryptographic** hash for
content de-duplication and change detection — not for security. The pure-Tcl
implementation provides the 32-bit variant and matches the reference xxHash32
bit for bit (verified against the canonical vectors and python-xxhash).

Pure Tcl, 8.6+ / 9.x. No dependencies.

## Commands

```tcl
tuxxhash::xxh32     data ?seed?   ;# -> 8 hex chars
tuxxhash::xxh32file path ?seed?   ;# -> 8 hex chars (whole file)
```

`data` is hashed as **bytes**. A binary string (e.g. a file's contents) is used
as-is; a plain text string is hashed as its UTF-8 bytes — encode explicitly with
`encoding convertto` if you need a specific encoding. `seed` is an optional
32-bit integer (default 0).

## Example

```tcl
package require tclutils::tuxxhash
namespace import ::tclutils::tuxxhash::*

xxh32 "The quick brown fox jumps over the lazy dog"   ;# -> e85ea4de
xxh32 "" 0                                            ;# -> 02cc5d05
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
| `IO` | `xxh32file` could not open the file |

## Testing

`tests/tuxxhash.test` checks the output against reference vectors (empty, short,
16-byte block boundary, long, seeded, binary bytes) and the file path. Set
`TCLUTILS_TM` to the module directory and run with `tclsh` (passes on 8.6 and
9.0).
