# tclutils::tubase32

RFC 4648 base32 (and base32hex) encode/decode in pure Tcl. Tcl core provides
base64 but not base32, so this fills the gap with a matching API.

## API

```tcl
set b32  [::tclutils::tubase32::encode $bytes]
set data [::tclutils::tubase32::decode $b32]
```

Commands:

- `encode data ?-pad bool? ?-hex bool?` — base32 string. `-pad 0` omits the
  trailing `=`; `-hex 1` uses the base32hex alphabet (RFC 4648 §7). Default
  `-pad 1 -hex 0`.
- `decode text ?-hex bool?` — back to a binary string. Whitespace and `=`
  padding are ignored; input is case-insensitive. The tail is checked as in
  RFC 4648 §3.5: the number of data characters must be one `encode` produces
  (a multiple of 8 plus 0, 2, 4, 5 or 7), and the bits left after the last
  whole byte must be zero. `decode MY` is `f`; `decode MZ` is an error.
- `encodeFile path ?-pad bool? ?-hex bool?` — encode a file's bytes.
- `decodeFile path ?-hex bool?` — decode a file's text.

Unlike `tclutils::tubase64::decode` (which returns an empty string for text
that is not base64), invalid base32 raises an error:

| Error code | When |
|---|---|
| `{TCLUTILS TUBASE32 CHAR}` | a character outside the alphabet |
| `{TCLUTILS TUBASE32 LENGTH}` | 1, 3 or 6 data characters in the last group |
| `{TCLUTILS TUBASE32 BITS}` | non-zero bits after the last byte |
| `{TCLUTILS COMMON BOOLEAN -pad}` / `-hex` | option value not a boolean |
