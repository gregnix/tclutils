# tclutils::tubin

Binary helper primitives in pure Tcl.

`tubin` is the shared binary layer for modules such as `tuhexdump`,
`tuhexedit`, and later byte-oriented parsers.

## Package

```tcl
package require tclutils::tubin 0.1
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
