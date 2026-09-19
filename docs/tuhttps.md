# tclutils::tuhttps

One place for the HTTPS policy of the modules that use the core `http` package
with `tls`: `tufetch`, `tudav`, `tupostgrest`. Builds a **verifying**
`::tls::socket` command and registers `https` only for the duration of a
script.

Needs the `tls` package when `socketCmd` is called (loaded lazily). Tcl 8.6+
and 9.x.

## Why it exists

`::http::register` is **global** to the interpreter. Up to tclutils 0.62.0 the
three modules each registered `https` themselves, with three different policies,
and never undid it — whoever registered last decided for everybody:

| module (≤ 0.62.0) | registered | verified? |
|---|---|---|
| `tufetch` 0.3 | on every call | no (`-require 0`) |
| `tupostgrest` 0.1 | on every request | yes, unless `-insecure 1` |
| `tudav` 0.1 | once, for good | tls 2.0 yes; **tls 1.x no** |

Measured 2026-09-19 against a local self-signed server: after one `tufetch`
call, every later `::http::geturl https://…` in the process accepted the forged
certificate. Under Tcl 8.6 `tudav` never verified at all.

## API

```tcl
::tclutils::tuhttps::socketCmd ?-insecure 0|1? ?-cafile path? ?-host name?
::tclutils::tuhttps::with prefix script
::tclutils::tuhttps::caFile
```

- `socketCmd` — returns a command prefix for `::http::register https 443 …`.
  - Default: verifies (`-require 1`).
  - `-cafile path` — verify against this CA bundle.
  - `-insecure 1` — accept any certificate. The only way to `-require 0`.
  - `-host name` — the request's host; an IP literal gets no SNI, because some
    tls builds reject an IP as SNI name ("failed to use socket").
- `with prefix script` — runs `script` in the caller's frame with `https`
  registered to `prefix`; afterwards the previous registration is restored (or
  removed, if there was none), also when the script raises an error. Returns the
  script's result. Do not use `return` inside the script.
- `caFile` — the CA bundle used for tls 1.x, or `""`.

```tcl
set prefix [::tclutils::tuhttps::socketCmd -host example.org]
set tok [::tclutils::tuhttps::with $prefix {::http::geturl https://example.org/}]
```

## tls 1.x and the CA store

`tls` 2.0 (Tcl 9) uses the OpenSSL default paths and needs no file. `tls` 1.x
(the usual package on Tcl 8.6, also on Windows) does **not** find the system CA
store: with `-require 1` and no `-cafile`, every real HTTPS request fails. For
tls < 2.0 `socketCmd` therefore looks for a bundle, in this order:

1. `$env(SSL_CERT_FILE)`
2. `/etc/ssl/certs/ca-certificates.crt` (Debian, Ubuntu)
3. `/etc/pki/tls/certs/ca-bundle.crt` (RHEL, Fedora)
4. `/etc/ssl/ca-bundle.pem` (openSUSE)
5. `/etc/ssl/cert.pem` (macOS, Alpine, BSD)
6. `/usr/local/etc/openssl/cert.pem`

If none is found it raises `NOCA`, whose message names the way out
(`-cafile`, `SSL_CERT_FILE`). It does not fall back to "no verification".
On Windows with tls 1.x, set `SSL_CERT_FILE` or pass `-cafile`.

Not measured: tls 2.0 on Windows. Whether its default paths find a CA store
there depends on the OpenSSL build. If not, the handshake fails loudly
(`certificate verify failed`), and `-cafile` is the way out.

## Errors

| errorcode | meaning |
|---|---|
| `{TCLUTILS TUHTTPS NOTLS}` | the `tls` package is not available |
| `{TCLUTILS TUHTTPS CAFILE}` | `-cafile` is not a readable file |
| `{TCLUTILS TUHTTPS NOCA}` | tls < 2.0 and no CA bundle found |
| `{TCLUTILS COMMON OPTION <opt>}` | unknown option (message lists the known ones) |
| `{TCLUTILS COMMON BOOLEAN -insecure}` | `-insecure` is not a boolean |

## What it does not see

The registration is scoped, not locked. A caller that registers `https` itself
after `with` has started, or an asynchronous `::http::geturl -command …` the
application started while a `with` script runs, can still meet a different
registration.

## Tests

`tests/tuhttps.test` runs a local HTTPS server in a child process
(`tests/data/https-server.tcl`, self-signed certificate for localhost and
127.0.0.1 in `tests/data/`, test use only). Both directions are checked:
rejected by default, accepted with the certificate as `-cafile` or with
`-insecure 1`, and the registration restored — also after an error.
