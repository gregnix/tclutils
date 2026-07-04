# tclutils::tupostgrest

A minimal, Tk-free client for a [PostgREST](https://postgrest.org) backend. It
builds the request URL / query / JSON body, sends it over http(s) with an
optional bearer token, parses the JSON response into Tcl dicts/lists and turns a
PostgREST error response into a Tcl error. Pure Tcl, Tcl/Tk 8.6+ / 9.x.

Dependencies: `http` (+ `tls` for https), `tclutils::tujson`, `tclutils::tuurl`.

## Commands

```tcl
tupostgrest::new baseUrl ?-token jwt? ?-timeout ms? ?-header {k v ...}? ?-schema name? ?-insecure 0|1?
tupostgrest::token  client jwt
tupostgrest::get    client table ?-filters {col val ...}? ?-select s? ?-order s? ?-limit n? ?-offset n?
tupostgrest::insert client table row   ?-return 0|1?
tupostgrest::update client table patch ?-filters {..}? ?-return 0|1?
tupostgrest::delete client table       ?-filters {..}? ?-return 0|1?
tupostgrest::rpc    client fn ?argsDict?
tupostgrest::request client method path ?-query {..}? ?-body json? ?-header {..}? ?-prefer s?
```

A **client** is an opaque dict returned by `new`; pass it as the first argument.
`token` returns a copy carrying a (new) JWT.

### Filters

`-filters` is a flat list of `column value` pairs where *value* is the native
PostgREST operator expression; both sides are URL-encoded (UTF-8 safe):

```tcl
-filters {extension eq.pdf name like.*müller* id in.(1,2,3)}
# -> ?extension=eq.pdf&name=like.%2Am%C3%BCller%2A&id=in.%281%2C2%2C3%29
```

`-order`, `-select`, `-limit`, `-offset` map straight to the PostgREST query
parameters (`order=modified_at.desc`, `select=id,filename`, ...).

### Row values and types

A row/patch is a Tcl dict. Values are JSON **strings** unless wrapped:

```tcl
tupostgrest::num 12345    ;# JSON number
tupostgrest::bool 1       ;# JSON true / false
tupostgrest::null         ;# JSON null

tupostgrest::insert $c documents [dict create \
    filename report.pdf filesize [tupostgrest::num 12345] active [tupostgrest::bool 1]]
# body: {"filename":"report.pdf","filesize":12345,"active":true}
```

(PostgREST coerces JSON strings into the target column type, so plain strings
are usually fine; the wrappers give explicit control where it matters.)

### HTTPS and self-signed certificates

For an `https://` base URL the client registers a TLS socket automatically (the
`tls` package must be present). Two cases need attention when the server is an
internal one reached by **IP address** with a **self-signed** certificate:

- **SNI with an IP.** A TLS server name (SNI) must be a host name, not an IP
  literal; some `tls` builds reject it and `http` then fails with
  *"failed to use socket"*. The client therefore sends SNI only for real host
  names and omits it for IPv4/IPv6 literals — no option needed.
- **Certificate validation.** A self-signed certificate is not signed by a CA.
  Pass `-insecure 1` to accept it without validation:

```tcl
set c [tupostgrest::new https://192.168.158.33 -token $jwt -insecure 1]
```

`-insecure` defaults to `0`. Use it only for trusted internal endpoints; with a
CA-signed certificate and a host name, leave it off.

### Reading and writing

`get` returns a Tcl list of row dicts. `insert`/`update`/`delete` default to
`Prefer: return=representation` (`delete` to `minimal`) — with `-return 1` the
affected rows are returned, with `-return 0` an empty string. `rpc` calls a
stored function via `POST /rpc/<fn>`.

## Example

```tcl
package require tclutils::tupostgrest
namespace import ::tclutils::tupostgrest::*

set c [new https://dms.example.com -token $jwt]

# newest 50 PDFs
set docs [get $c documents -filters {extension eq.pdf} -order modified_at.desc -limit 50]
foreach d $docs { puts "[dict get $d id]  [dict get $d filename]" }

# add a document row
set new [insert $c documents [dict create \
    filename rechnung.pdf filepath /share/2026/rechnung.pdf \
    filesize [num 84213] filehash $sha]]

# mark it indexed
update $c documents [dict create indexed_at now] -filters {id eq.[dict get [lindex $new 0] id]}

# full-text search via a stored function
set hits [rpc $c search_documents [dict create q "rechnung müller"]]
```

## Errors

Error code `{TCLUTILS TUPOSTGREST <REASON>}`:

| REASON | When |
|--------|------|
| `OPTION` | unknown option or bad usage |
| `HTTP` | backend returned status >= 400 (4th element is the status; message from the error JSON) |
| `TRANSPORT` | the request could not be sent / no response |
| `PARSE` | the response body was not valid JSON |

## Testing

`tests/tupostgrest.test` replaces the internal `_transport` proc with a mock, so
the whole client (URL/query/body/headers/auth/parse/errors) is verified headless
without a server. Set `TCLUTILS_TM` to the module directory and run with
`tclsh`.
