# tclutils::tuldif

LDIF (RFC 2849) reader/writer. An entry is an ordered list of {attribute value}
pairs (the dn is the "dn" attribute); multi-valued attributes are repeated
pairs. Base64 values (`attr:: ...`) are decoded via tclutils::tubase64 and
re-encoded on output when a value is not LDIF-safe.

## Commands
```tcl
tuldif::parse  ldifText ?-binary attrs?   ;# -> list of entries
tuldif::toLdif entries ?-binary attrs?    ;# -> LDIF text
tuldif::dn         entry           ;# -> dn ("" if none)
tuldif::get        entry attr      ;# -> list of values (nocase)
tuldif::attributes entry           ;# -> attribute names (first-seen order)
tuldif::toDict     entry           ;# -> dict attr -> list of values
```
Continuation lines (a leading space) are unfolded automatically.

Values are text. RFC 2849 values are UTF-8, so a base64 value (`attr:: ...`)
is decoded from UTF-8 after the base64 step, and `toLdif` encodes a value to
UTF-8 before base64 (`Hällo` -> `SMOkbGxv`). Base64 bytes that are not valid
UTF-8 come back unchanged, one character per byte.

Binary attributes (0.3): their values are byte strings, one character per
byte. `parse` keeps the decoded bytes (also when they happen to be valid
UTF-8), `toLdif` writes them as base64 unchanged; up to 0.2 `toLdif` encoded
them as UTF-8 first, so the base64 held other bytes. Binary are
`jpegPhoto`, `photo`, `audio`, `thumbnailPhoto`, `thumbnailLogo`,
`userCertificate`, `cACertificate`, `crossCertificatePair`,
`certificateRevocationList`, `authorityRevocationList`,
`deltaRevocationList`, `userSMIMECertificate`, `userPKCS12`, `objectGUID`,
`objectSid`, `msExchMailboxGuid`, every attribute with the option `;binary`
(`userCertificate;binary`), and the names given with `-binary`. A binary
value with a character above `\xFF` raises `{TCLUTILS TULDIF BINARY}`.

Comment lines (`#`) are not kept.

`toLdif` writes a value as base64 when it is not a SAFE-STRING: it starts with
a space, `:` or `<`, ends with a space, or contains a character outside 32..126
(control characters, non-ASCII).

Only content records are read. A change record (`changetype: add|modify|...`)
raises `{TCLUTILS TULDIF CHANGETYPE}`.

| Error code | When |
|---|---|
| `{TCLUTILS TULDIF SYNTAX}` | a line without `:` |
| `{TCLUTILS TULDIF CHANGETYPE}` | a change record |
| `{TCLUTILS TULDIF BINARY}` | `toLdif`: a binary value that is not bytes |
| `{TCLUTILS TULDIF OPTION}` | an option other than `-binary` |

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tuldif::addAttr entry attr value               ;# return a copy of an entry with an {attr value} pair appended
tuldif::removeAttr entry index                 ;# return a copy of an entry with the pair at index removed
tuldif::setAttr entry index attr value         ;# return a copy of an entry with the pair at index replaced
```
