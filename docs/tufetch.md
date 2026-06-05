# tclutils::tufetch

A tiny HTTP(S) helper: fetch a URL into memory (`get`) or to a file
(`download`), byte-safe. Transport order: native Tcl `http` + `tls` (the `tls`
package is loaded lazily, like `tclutils::tudav`); if that is unavailable it
falls back to `curl` or `wget` located via `auto_execok`. Supports GET and POST
with custom headers and a request body, so higher-level clients (e.g.
`tclutils::tusparql`) can build on it.

Not dependency-free: needs the core `http` package and either `tls` or a
`curl`/`wget` binary. Meant as an optional helper module.

## API

```tcl
::tclutils::tufetch::get https://example.com/data.json          ;# -> text (UTF-8)
::tclutils::tufetch::download https://example.com/f.bin /tmp/f  ;# -> native|curl|wget

# POST with headers and a request body:
::tclutils::tufetch::get $url -method post -data $body \
    -type application/sparql-query \
    -headers {Accept application/sparql-results+json}
```

Commands:

- `get url ?opts?` — return the response body as UTF-8 text.
- `download url path ?opts?` — save the body to `path` (raw bytes); returns the
  transport used (`native`, `curl` or `wget`).

Options (both commands):

- `-timeout ms` (default 30000), `-redirects n` (default 5).
- `-method get|post` (default get).
- `-headers {k v k v ...}` — extra request headers.
- `-data <body>` — request body (pair with `-method post`).
- `-type <content-type>` — content type for the body.

Errors: an HTTP status outside 2xx → `{TCLUTILS TUFETCH HTTP <code>}` (same on
the native and the curl path); too many redirects → `{TCLUTILS TUFETCH REDIRECT}`;
no transport available → `{TCLUTILS TUFETCH NOMETHOD}`. The `wget` fallback does
not translate HTTP status — a 4xx/5xx there surfaces as a `CHILDSTATUS` error.

The request-line construction lives in pure helpers (`_nativeOpts`, `_curlArgs`,
`_wgetArgs`), so it can be tested without a network. Verified on Tcl 8.6 and 9.x;
the native `http`+`tls` path and the curl fallback were exercised against live
endpoints.
