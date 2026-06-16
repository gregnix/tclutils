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
Error code: `{TCLUTILS TULDIF SYNTAX}`.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tuldif::addAttr entry attr value               ;# return a copy of an entry with an {attr value} pair appended
tuldif::removeAttr entry index                 ;# return a copy of an entry with the pair at index removed
tuldif::setAttr entry index attr value         ;# return a copy of an entry with the pair at index replaced
```
