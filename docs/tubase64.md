# tclutils::tubase64

Base64 helpers using Tcl core `binary encode base64` and `binary decode base64`.

## API

```tcl
set b64 [::tclutils::tubase64::encode $bytes]
set data [::tclutils::tubase64::decode $b64]
```

Commands:

- `encode data ?-maxlen n? ?-encoding binary|utf-8?`
- `decode text ?-encoding binary|utf-8?`
- `encodeFile path ?-maxlen n?`
- `decodeFile path`

## Bytes and text

`encode` takes bytes by default (`-encoding binary`): each character is one
byte. A character above 255 is `{TCLUTILS TUBASE64 BYTES}` on Tcl 8.6 and
9.0 alike; Tcl 8.6 alone would keep only the low byte. For text pass
`-encoding utf-8`; `decode -encoding utf-8` turns the bytes back into text
(0.2).

```tcl
::tclutils::tubase64::encode "Jörg €" -encoding utf-8   ;# SsO2cmcg4oKs
::tclutils::tubase64::decode SsO2cmcg4oKs -encoding utf-8 ;# Jörg €
::tclutils::tubase64::encode "Jörg"                      ;# SvZyZw== (ö as byte f6)
```

`tuhash` and `tuxxhash` default to `utf-8` instead, because they are mostly
used on text; `tubase64`, `tubase32` and `tucrc` default to bytes, because
their input is mostly file or image data.

Errors: `MAXLEN`, `BYTES`, `ENCODING`.
