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
  Characters that are not percent-encoded count as their UTF-8 bytes, so
  `J%C3%B6rg` and an already decoded `Jörg` give the same text (0.2; under
  Tcl 9 0.1 broke off on the second). A `%` without two hex digits stays,
  `%00` gives a NUL character. Invalid UTF-8 (`%FF`) stays as the bytes, one
  character 0–255 each (0.1 broke off under Tcl 9). The result is text, not a
  checked file name: test it before it reaches `open` or a path.
- `buildQuery dict ?-plus bool?` — `k=v&k2=v2` (default `-plus 1`).
- `parseQuery str ?-plus bool?` — parse into a dict (default `-plus 1`). A key
  that occurs more than once (`a=1&a=2`, e.g. checkboxes) keeps only its last
  value; split the string yourself at `&` when every value counts.
