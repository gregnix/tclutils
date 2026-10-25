# tclutils::tuldif

LDIF (RFC 2849) reader/writer. An entry is an ordered list of {attribute value}
pairs (the dn is the "dn" attribute); multi-valued attributes are repeated
pairs. Base64 values (`attr:: ...`) are decoded via tclutils::tubase64 and
re-encoded on output when a value is not LDIF-safe.

## Commands
```tcl
tuldif::parse  ldifText            ;# -> list of entries
tuldif::toLdif entries             ;# -> LDIF text
tuldif::dn         entry           ;# -> dn ("" if none)
tuldif::get        entry attr      ;# -> list of values (nocase)
tuldif::attributes entry           ;# -> attribute names (first-seen order)
tuldif::toDict     entry           ;# -> dict attr -> list of values
```
Continuation lines (a leading space) are unfolded automatically.

Values are text. RFC 2849 values are UTF-8, so a base64 value (`attr:: ...`)
is decoded from UTF-8 after the base64 step, and `toLdif` encodes a value to
UTF-8 before base64 (`Hällo` -> `SMOkbGxv`). Base64 bytes that are not valid
UTF-8 (a binary attribute such as `jpegPhoto`) come back unchanged, one
character per byte; written back through `toLdif` such a value is encoded as
UTF-8 again and is therefore not byte-exact.

`toLdif` writes a value as base64 when it is not a SAFE-STRING: it starts with
a space, `:` or `<`, ends with a space, or contains a character outside 32..126
(control characters, non-ASCII).

Only content records are read. A change record (`changetype: add|modify|...`)
raises `{TCLUTILS TULDIF CHANGETYPE}`.

| Error code | When |
|---|---|
| `{TCLUTILS TULDIF SYNTAX}` | a line without `:` |
| `{TCLUTILS TULDIF CHANGETYPE}` | a change record |

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tuldif::addAttr entry attr value               ;# return a copy of an entry with an {attr value} pair appended
tuldif::removeAttr entry index                 ;# return a copy of an entry with the pair at index removed
tuldif::setAttr entry index attr value         ;# return a copy of an entry with the pair at index replaced
```
