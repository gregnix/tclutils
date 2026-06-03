# tclutils::tuurl

URL percent-encoding/decoding and query strings (RFC 3986). Unreserved
characters `A-Z a-z 0-9 - . _ ~` pass through; everything else is encoded over
the UTF-8 bytes.

## API

```tcl
::tclutils::tuurl::encode "a b/c"        ;# a%20b%2Fc
::tclutils::tuurl::decode "%C3%A4"        ;# (UTF-8 -> a-umlaut)
::tclutils::tuurl::buildQuery {q "x y" p 2}   ;# q=x+y&p=2
```

Commands:

- `encode str ?-plus bool?` — percent-encode. `-plus 1`: space becomes `+`.
- `decode str ?-plus bool?` — percent-decode. `-plus 1`: `+` becomes space.
- `buildQuery dict ?-plus bool?` — `k=v&k2=v2` (default `-plus 1`).
- `parseQuery str ?-plus bool?` — parse into a dict (default `-plus 1`).
