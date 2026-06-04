# tclutils::tudav

A minimal WebDAV / CardDAV / CalDAV client. Create a client bound to a base URL
and credentials, then run PROPFIND / REPORT / GET / PUT / DELETE. Multistatus
responses are parsed into resource dicts (href, status, code, etag,
contenttype, collection, displayname, and `data` for inline calendar/address data).

Built on the Tcl core `http` package; **https uses the `tls` package**, loaded
lazily on first https request. Basic auth uses `tclutils::tubase64`; entity
text is decoded with `tclutils::tuxml`. The client does not parse resource
bodies — feed a fetched vCard to `tclutils::tuvcard` or an iCalendar to
`tclutils::tuical`.

## API

```tcl
set c [::tclutils::tudav::client https://dav.example.com/addressbooks/me/contacts/ \
        -user alice -password secret]
foreach r [::tclutils::tudav::listResources $c] {
    set vcf  [::tclutils::tudav::get $c [dict get $r href]]
    set card [::tclutils::tuvcard::parse $vcf]
    # ...
}
::tclutils::tudav::destroy $c
```

Commands:

- `client url ?-user u? ?-password p? ?-headers {k v ...}?` → client token.
- `propfind c ?-path p? ?-depth 0|1|infinity? ?-props {...}? ?-body xml?` →
  list of resource dicts.
- `report c path xmlBody ?-depth d?` → resource dicts (multiget / calendar-query).
- `listResources c ?-path p?` → non-collection entries `{href etag contenttype}`.
- `get c path` → body (errors on non-2xx).
- `put c path data ?-type ct? ?-etag e?` -> returns the new ETag (if the server
  reports one); `delete c path ?-etag e?`.
- `lastStatus c` → last HTTP status line ; `destroy c`.
- `calendarQuery c path fromIso toIso` — CalDAV calendar-query REPORT for
  VEVENTs in a time range; each resource dict's `data` holds the inline iCal.
- `addressbookMultiget c path hrefs` — CardDAV multiget; `data` holds vCards.
- `mkCollection c path ?-displayname n?` — create a plain WebDAV collection.
- `mkAddressbook c path ?-displayname n?` — create a CardDAV address book.
- `mkCalendar c path ?-displayname n?` — create a CalDAV calendar (MKCALENDAR).
- `listCollections c ?-path p?` — discover child collections under `p`; dicts
  `{href displayname kind}` with `kind` in addressbook/calendar/collection.
- `calendarMultiget c path hrefs` — CalDAV multiget; `data` holds iCalendar.
- `currentUserPrincipal c ?-path p?` — DAV:current-user-principal href.
- `calendarHomeSet c principal` / `addressbookHomeSet c principal` — home hrefs.
- `wellKnown c caldav|carddav` — RFC 6764 redirect target, or "".
- `discover c ?-path p?` — `{principal <href> calendarHome <href> addressbookHome <href>}`.
- `getProperties c ?-path p? ?-props {...}?` — read collection properties; dict
  of short-name -> value. Known: displayname, calendar-color, calendar-description,
  addressbook-description, supported-calendar-component-set (a list of comp names).
- `proppatch c path props` — set properties (PROPPATCH). `props` is a dict of
  short-name -> value (displayname, calendar-color `#rrggbb[aa]`, calendar-description,
  addressbook-description). The component set is create-time only and read-only here.
- `syncCollection c path ?-token t?` — RFC 6578 incremental sync. Returns
  `{token <new> changes <resource dicts>}`; empty `-token` does the initial
  sync, a returned token feeds the next call. In incremental results a change
  with `code` 404 means the resource was removed.

Verified end to end against Radicale 3.7 (provision, PUT, REPORT, GET, DELETE)
on Tcl 8.6 and 9.x.

Errors: HTTP failures → `{TCLUTILS TUDAV HTTP}`; missing tls for https →
`{TCLUTILS TUDAV TLS}`.
