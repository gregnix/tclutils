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
