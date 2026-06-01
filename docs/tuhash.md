# tuhash

Pure-Tcl cryptographic digests: **SHA-256**, **SHA-1**, **MD5**. Clean-room
implementations of FIPS 180-4 / RFC 1321, so no tcllib or binary extension is
required. All outputs are verified against the standard test vectors.

## Commands

| Command | Result |
|---------|--------|
| `sha256 data ?-encoding utf-8\|binary?` | hex SHA-256 of a string |
| `sha1   data ?-encoding ...?` | hex SHA-1 |
| `md5    data ?-encoding ...?` | hex MD5 |
| `sha256File path` / `sha1File path` / `md5File path` | digest of a file's bytes |

`-encoding utf-8` (default) hashes the UTF-8 bytes of the string, matching what
`sha256sum`/`md5sum` produce in a UTF-8 locale. `-encoding binary` treats the
argument as raw bytes (each character a byte 0-255). The `*File` variants read
the exact bytes on disk.

```tcl
package require tclutils::tuhash
tuhash::sha256 "abc"          ;# ba7816bf...f20015ad
tuhash::md5    "abc"          ;# 900150983cd24fb0d6963f7d28e17f72
tuhash::sha256File config.tcl ;# digest of the file
```

Errors use `{TCLUTILS TUHASH ...}`.
