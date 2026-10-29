# tclutils::tucrc

Checksum helpers using Tcl core `zlib`.

## API

```tcl
set crc [::tclutils::tucrc::crc32 $bytes]
puts [::tclutils::tucrc::hex32 $crc]
```

Commands:

- `crc32 data ?initValue? ?-encoding binary|utf-8?`
- `adler32 data ?initValue? ?-encoding binary|utf-8?`
- `crc32File path`
- `adler32File path`
- `hex32 value`

## Bytes and text

`crc32` and `adler32` take bytes by default (`-encoding binary`). A
character above 255 is `{TCLUTILS TUCRC BYTES}` on Tcl 8.6 and 9.0 alike;
Tcl 8.6 alone would keep only the low byte. With `-encoding utf-8` the text
is converted first, and the checksum equals `crc32File` of a UTF-8 file with
that text (0.2). See `tubase64` for why the digests in `tuhash` default to
`utf-8` instead.

Errors: `BYTES`, `ENCODING`, `OPTION`.
