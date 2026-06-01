# tclutils::tuical

iCalendar (RFC 5545) reader/writer. A component is a dict
`{type T props {prop ...} components {component ...}}`; a property is
`{name N value V params {k v ...}}`. parse returns the list of top-level
components (usually one VCALENDAR); toIcs serializes with 75-char line folding.

## Commands
```tcl
tuical::parse icsText             ;# -> list of top-level components
tuical::toIcs comp|comps           ;# -> iCalendar text (CRLF, folded)
tuical::components comp ?type?     ;# direct children, optional type filter
tuical::properties comp ?name?     ;# property dicts, optional name filter
tuical::property   comp name       ;# first value of a property ("")
tuical::find  comp|comps type      ;# all descendants of a type
tuical::events comp|comps          ;# all VEVENT components
tuical::escapeText / unescapeText  ;# RFC 5545 TEXT escaping
```
Folded lines (continuation starting with space/tab) are unfolded automatically.
Property values are kept raw for exact round-tripping.
Error code: `{TCLUTILS TUICAL SYNTAX}`.
