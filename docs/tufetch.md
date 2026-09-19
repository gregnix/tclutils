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
- `-headers {k v k v ...}` — extra request headers. (0.4 fixes the wget
  fallback: up to 0.3 each header became two arguments there, and wget took the
  value for a second URL.)
- `-data <body>` — request body (pair with `-method post`).
- `-type <content-type>` — content type for the body.
- `-cafile <file>` — verify the server certificate against this CA bundle
  (an internal CA, or a server's own self-signed certificate).
- `-insecure 0|1` (default 0) — accept **any** certificate. For a trusted
  internal server only; prefer `-cafile`.

## Certificate verification (0.4)

Every transport verifies the server certificate, and `-insecure 1` switches it
off on every transport (`curl -k`, `wget --no-check-certificate`). The same URL
now gives the same answer whichever transport is used.

Up to 0.3 the native path registered `https` **globally** with `-require 0`:
after one `tufetch` call, every `::http::geturl https://…` in the process —
the application's own included — accepted any certificate, while the curl/wget
paths did verify. Since 0.4 the native path goes through `tclutils::tuhttps`:
`https` is registered only for the duration of the request, and the previous
registration is restored afterwards.

`tls` 1.x (the usual package on Tcl 8.6, also on Windows) does not find the
system CA store by itself. `tufetch` then looks for a CA bundle
(`SSL_CERT_FILE`, then the usual Linux/BSD/macOS paths, see `tuhttps`). If none
is found the native path steps aside and curl/wget are tried — they bring their
own CA store. If neither exists, the error is `NOMETHOD` and its message names
the way out (`-cafile`, `SSL_CERT_FILE`). It does **not** fall back to fetching
unverified.

**Behaviour change:** a caller that relied on 0.3 silently accepting a
self-signed or internal certificate now gets `CONNECT` (the message suggests
`-cafile` / `-insecure 1`). On Windows with Tcl 8.6 and no curl, an HTTPS fetch
without a CA bundle now fails with `NOMETHOD` instead of succeeding unverified.

## Errors

Errors carry a structured errorcode (modelled on the `www` package) so callers
can match at the granularity they need with `try`/`trap` — errorcodes are
prefix-matched:

| errorcode | meaning |
|---|---|
| `{TCLUTILS TUFETCH HTTP <class> <code>}` | HTTP status outside 2xx, e.g. `{… HTTP 4XX 404}`, `{… HTTP 5XX 503}` |
| `{TCLUTILS TUFETCH URL}` | unsupported or invalid URL (only `http`/`https`) |
| `{TCLUTILS TUFETCH TIMEOUT}` | the request timed out |
| `{TCLUTILS TUFETCH CONNECT}` | connection/DNS/transport failure |
| `{TCLUTILS TUFETCH REDIRECT}` | too many redirects |
| `{TCLUTILS TUFETCH NOMETHOD}` | no transport available (also: tls 1.x without CA bundle and no curl/wget) |
| `{TCLUTILS TUFETCH CAFILE}` | the `-cafile` given is not readable |

```tcl
try {
    set page [::tclutils::tufetch::get $url]
} trap {TCLUTILS TUFETCH HTTP 4XX 404} {} {
    # exactly 404
} trap {TCLUTILS TUFETCH HTTP 4XX} {} {
    # any client error
} trap {TCLUTILS TUFETCH HTTP 5XX} {err} {
    # any server error
} trap {TCLUTILS TUFETCH} {err opts} {
    # timeout, connect, redirect, bad URL, no transport ...
}
```

The HTTP and transport classification lives in pure helpers (`_httpClass`,
`_statusReason`, `_curlExitReason`), so the taxonomy is tested without a network.
The `wget` fallback does not translate HTTP status — a 4xx/5xx there surfaces as
a `CHILDSTATUS` error. NOTE: as of 0.3 the HTTP errorcode gained the `<class>`
element; code that trapped the old 3-element `{TCLUTILS TUFETCH HTTP <code>}`
exactly should use the prefix `{TCLUTILS TUFETCH HTTP}`.

The request-line construction lives in pure helpers (`_nativeOpts`, `_curlArgs`,
`_wgetArgs`), so it can be tested without a network. Verified on Tcl 8.6 and 9.x;
the native `http`+`tls` path and the curl fallback were exercised against live
endpoints. Certificate handling is tested offline against a local self-signed
server (`tests/data/https-server.tcl`), in both directions: rejected by default,
accepted with `-cafile` or `-insecure 1`, and the process-wide `https`
registration left as it was found.
