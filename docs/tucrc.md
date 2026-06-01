# tclutils::tucrc

Checksum helpers using Tcl core `zlib`.

## API

```tcl
set crc [::tclutils::tucrc::crc32 $bytes]
puts [::tclutils::tucrc::hex32 $crc]
```

Commands:

- `crc32 data ?initValue?`
- `adler32 data ?initValue?`
- `crc32File path`
- `adler32File path`
- `hex32 value`
