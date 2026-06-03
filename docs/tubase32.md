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
  padding are ignored; input is case-insensitive.
- `encodeFile path ?-pad bool? ?-hex bool?` — encode a file's bytes.
- `decodeFile path ?-hex bool?` — decode a file's text.

Errors use error code `{TCLUTILS TUBASE32 CHAR}` for an invalid input character.
