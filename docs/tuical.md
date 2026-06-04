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

## VTODO / VJOURNAL accessors

```tcl
set comps [tuical::parse $ics]
tuical::todos    $comps     ;# list of VTODO components (recursive, like events)
tuical::journals $comps     ;# list of VJOURNAL components

tuical::eventInfo   $vevent   ;# {uid summary description dtstart dtend location status categories}
tuical::todoInfo    $vtodo    ;# {uid summary description status priority percentComplete due dtstart completed categories}
tuical::journalInfo $vjournal ;# {uid summary description dtstart status categories}

# build a component (e.g. to PUT a task via tudav)
set todo [tuical::newComponent VTODO {UID x9 SUMMARY {Call Bob} STATUS NEEDS-ACTION}]
set ics  [tuical::toIcs [list $todo]]
```

The `*Info` helpers return a flat dict; missing properties are `""` and text
fields (summary/description/location) are unescaped. `newComponent` seeds
properties from a flat `{NAME value ...}` list and yields a component usable
with `addProperty`/`setProperty`/`toIcs`.
