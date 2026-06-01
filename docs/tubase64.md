# tclutils::tubase64

Base64 helpers using Tcl core `binary encode base64` and `binary decode base64`.

## API

```tcl
set b64 [::tclutils::tubase64::encode $bytes]
set data [::tclutils::tubase64::decode $b64]
```

Commands:

- `encode data ?-maxlen n?`
- `decode text`
- `encodeFile path ?-maxlen n?`
- `decodeFile path`
