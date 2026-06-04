# tclutils::turegistry

A small keyed value registry (service locator / bag). Store values under keys
and fetch them with a required-get that errors on a missing key.

## API

```tcl
set reg [::tclutils::turegistry::create]
::tclutils::turegistry::put $reg db $conn
::tclutils::turegistry::get $reg db            ;# -> $conn
::tclutils::turegistry::get $reg cache {}       ;# -> "" (default)
```

Commands:

- `create` → registry token.
- `put reg key value` → value.
- `get reg key ?default?` — missing key errors `{TCLUTILS TUREGISTRY KEY}`
  unless a default is supplied.
- `has reg key`, `keys reg ?pattern?`, `remove reg key`, `destroy reg`.
