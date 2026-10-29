# tclutils::tuvcard

vCard (RFC 6350 / 2426) reader/writer. parse returns a list of cards; a card is a
list of property dicts `{name N value V params {k v ...}}`. toVcf folds lines
at 75 octets, never inside a UTF-8 character (0.2; 0.1 counted characters);
every line ends with CRLF, the last one too (0.2; 0.1 left it off). Values
are kept raw for exact round-tripping.

Since 0.2: `BEGIN`/`END` in any case; a quoted parameter value may hold
`;` and `:` (`TYPE="work;cell"` is one value `work;cell`, written back in
quotes); a group prefix counts for the name (`item1.FN` is found by
`property`, `properties`, `get` and `fullName`, and stays `item1.FN` on
write); `addProperty` and `setProperty` refuse a value with a line break
(`{TCLUTILS TUVCARD VALUE}`).

```tcl
tuvcard::parse vcfText          ;# -> list of cards
tuvcard::toVcf card|cards        ;# -> vCard text (CRLF, folded, ends with CRLF)
tuvcard::property   card name    ;# first value ("")
tuvcard::properties card ?name?  ;# property dicts
tuvcard::get        card name    ;# list of values
tuvcard::names      card         ;# property names
tuvcard::fullName   card         ;# FN
```
Error code: `{TCLUTILS TUVCARD SYNTAX}`.

## Photos

```tcl
set ph [tuvcard::photo $card]
#  -> {kind none}
#  -> {kind uri    uri <url>   mime <type-or-"">}
#  -> {kind inline bytes <raw> mime <type>}

set card [tuvcard::setPhoto    $card image/png $bytes]          ;# 4.0 data: URI
set card [tuvcard::setPhoto    $card image/jpeg $bytes -version 3] ;# 3.0 ENCODING=b
set card [tuvcard::setPhotoUri $card https://example.com/me.jpg]
```

`photo` decodes inline photos (vCard 3.0 `ENCODING=b;TYPE=...` and 4.0 `data:` URIs)
to raw bytes and reports the MIME type (from the `TYPE` parameter, the data URI,
or sniffed via `tuimage`). `setPhoto`/`setPhotoUri` replace any existing PHOTO.
Reuses `tclutils::tubase64` and `tclutils::tuimage`.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tuvcard::addProperty card name value ?params?  ;# return a copy of a card with a property appended
tuvcard::removeProperty card index             ;# return a copy of a card with the property at index removed
tuvcard::setProperty card index name value ?params? ;# return a copy of a card with the property at index replaced
```
