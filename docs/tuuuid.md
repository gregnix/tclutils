# tclutils::tuuuid

UUID generation and inspection in pure Tcl. Supports version 4 (random) and
version 7 (Unix-time-ordered, RFC 9562). Random bytes come from `/dev/urandom`
when available, otherwise from `rand()` (non-cryptographic fallback).

## API

```tcl
set id  [::tclutils::tuuuid::generate]            ;# v4 by default
set id7 [::tclutils::tuuuid::generate -version 7] ;# time-ordered
```

Commands:

- `generate ?-version 4|7?` — a canonical UUID string (default 4).
- `v4` — random version-4 UUID.
- `v7` — time-ordered version-7 UUID (sorts by creation time).
- `nil` — the nil UUID `00000000-0000-0000-0000-000000000000`.
- `validate uuid` — 1 if `uuid` is a canonical UUID string, else 0.
- `version uuid` — the version digit (1..8); errors on an invalid UUID.

Errors: `{TCLUTILS TUUUID VERSION}` (bad `-version`),
`{TCLUTILS TUUUID INVALID}` (not a UUID).
