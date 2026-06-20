# tclutils::tubin

Binary helper primitives in pure Tcl.

`tubin` is the shared binary layer for modules such as `tuhexdump`,
`tuhexedit`, `tummdb`, and later byte-oriented parsers.

## Package

```tcl
package require tclutils::tubin 0.3
```

## Hex conversion

```tcl
set bytes [::tclutils::tubin::hexToBytes {50 4B 03 04}]
set hex   [::tclutils::tubin::bytesToHex $bytes]
```

## Unsigned integer readers

```tcl
::tclutils::tubin::u8     $bytes ?offset?
::tclutils::tubin::u16le  $bytes ?offset?
::tclutils::tubin::u32le  $bytes ?offset?
::tclutils::tubin::u64le  $bytes ?offset?
::tclutils::tubin::u16be  $bytes ?offset?
::tclutils::tubin::u32be  $bytes ?offset?
::tclutils::tubin::u64be  $bytes ?offset?
```

Offsets may be decimal or hex-like strings such as `0x100`.

## Variable-length big-endian integer

```tcl
::tclutils::tubin::uintbe $bytes ?offset? ?length?
```

Reads a big-endian unsigned integer of arbitrary byte length (0..N). A length
of `0` returns `0`. Useful for formats with non-power-of-two widths, e.g. the
24-bit tree records and 128-bit integers of the MaxMind DB format. Tcl's
big-integer support keeps values exact beyond 64 bits.

```tcl
::tclutils::tubin::uintbe [binary format ccc 1 2 3] 0 3   ;# -> 66051
```

## IEEE-754 float readers (big-endian)

```tcl
::tclutils::tubin::f32be  $bytes ?offset?   ;# single precision (4 bytes)
::tclutils::tubin::f64be  $bytes ?offset?   ;# double precision (8 bytes)
```

## Little-endian variants

```tcl
::tclutils::tubin::uintle $bytes ?offset? ?length?   ;# variable-length LE unsigned
::tclutils::tubin::f32le  $bytes ?offset?
::tclutils::tubin::f64le  $bytes ?offset?
```

## Signed integer readers (two's complement)

```tcl
::tclutils::tubin::i8     $bytes ?offset?
::tclutils::tubin::i16le  $bytes ?offset?
::tclutils::tubin::i16be  $bytes ?offset?
::tclutils::tubin::i32le  $bytes ?offset?
::tclutils::tubin::i32be  $bytes ?offset?
::tclutils::tubin::i64le  $bytes ?offset?
::tclutils::tubin::i64be  $bytes ?offset?
```

Each is the signed counterpart of the matching `uNN` reader.

## Reader cursor

A position-tracking view over a byte string, so parsers need not thread an
offset by hand.

```tcl
set rd [::tclutils::tubin::reader new $bytes ?offset?]

$rd u32be              ;# read and advance
$rd uintbe 3           ;# variable-length read and advance
$rd i16le
$rd f64be
$rd bytes 8            ;# read 8 raw bytes
$rd skip 4             ;# advance without reading
$rd seek 0             ;# absolute position
$rd tell               ;# current position
$rd remaining          ;# bytes left
$rd atEnd              ;# 1 at end of data
$rd destroy            ;# release the cursor
```

Read methods mirror the standalone readers: `u8`/`i8`, `u16le`/`u16be`/`i16le`/
`i16be`, the 32- and 64-bit variants, `f32le`/`f32be`/`f64le`/`f64be`, and
`uintbe`/`uintle` (which take a length).

## Unsigned integer packers

```tcl
::tclutils::tubin::packU8     255
::tclutils::tubin::packU16LE  0x1234
::tclutils::tubin::packU32LE  0x12345678
::tclutils::tubin::packU64LE  123456789
::tclutils::tubin::packU16BE  0x1234
::tclutils::tubin::packU32BE  0x12345678
::tclutils::tubin::packU64BE  123456789
```

## ASCII preview

```tcl
::tclutils::tubin::ascii $bytes
```

Non-printable bytes are rendered as `.`.

## Unsigned byte lists

```tcl
::tclutils::tubin::bytesToUnsignedList $bytes ?offset? ?length?
```

This returns a Tcl list of unsigned byte values in the range `0..255`. It is
useful for dump-style modules that need to iterate over bytes without repeating
`binary scan cu*` locally.
