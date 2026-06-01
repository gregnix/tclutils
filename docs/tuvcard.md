# tclutils::tuvcard

vCard (RFC 6350 / 2426) reader/writer. parse returns a list of cards; a card is a
list of property dicts `{name N value V params {k v ...}}`. toVcf serializes with
75-char line folding. Values are kept raw for exact round-tripping.

```tcl
tuvcard::parse vcfText          ;# -> list of cards
tuvcard::toVcf card|cards        ;# -> vCard text (CRLF, folded)
tuvcard::property   card name    ;# first value ("")
tuvcard::properties card ?name?  ;# property dicts
tuvcard::get        card name    ;# list of values
tuvcard::names      card         ;# property names
tuvcard::fullName   card         ;# FN
```
Error code: `{TCLUTILS TUVCARD SYNTAX}`.
