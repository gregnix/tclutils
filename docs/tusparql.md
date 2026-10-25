# tclutils::tusparql

A thin SPARQL client. It composes existing modules rather than reimplementing
anything: transport via `tclutils::tufetch` (GET, or POST `application/sparql-query`
for long queries), query-string building via `tclutils::tuurl`, and parsing of
the SPARQL 1.1 Results JSON via `tclutils::tujson`. The only SPARQL-specific work
is flattening the result bindings into plain `{var value ...}` dicts.

Not dependency-free (inherits `tufetch`'s http+tls / curl|wget requirement).

## API

```tcl
set ep https://query.wikidata.org/sparql
set q {SELECT ?item ?itemLabel WHERE {
    ?item wdt:P31 wd:Q476028 .
    SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
} LIMIT 10}
foreach row [::tclutils::tusparql::query $ep $q] {
    puts "[dict get $row item] -> [dict get $row itemLabel]"
}
set yes [::tclutils::tusparql::ask $ep {ASK { wd:Q1 wdt:P31 ?x }}]
```

Commands:

- `query endpoint sparql ?opts?` — run a SELECT; returns a list of row dicts, one
  per result, each mapping a bound variable → its value. Variables that are
  unbound in a row (e.g. behind `OPTIONAL`) are simply absent from that dict.
- `ask endpoint sparql ?opts?` — run an ASK; returns 1 or 0.

Options:

- `-method get|post` (default get; use post for long queries that would overflow
  a GET URL).
- `-timeout ms` (default 30000).
- `-accept type` (default `application/sparql-results+json`) — the `Accept`
  header. The answer is always parsed as SPARQL Results JSON.
- `-headers {k v ...}` — extra request headers. An `Accept` among them (any
  case) replaces `-accept`; the header is sent once.

With `-method get` the query goes into the URL as `query=...&format=json`. An
endpoint that already carries a query string (`.../sparql?key=1`) gets the
parameters appended with `&`.

When the response has no `head.vars`, the row dicts use the variables of all
bindings (first-seen order), not only those of the first row.

Localized labels come from the `wikibase:label` service
(`bd:serviceParam wikibase:language "..."`). When matching by Wikipedia article,
remember Wikidata stores sitelink IRIs in Unicode while a captured URL is usually
percent-encoded — decode (UTF-8 aware) before building a `VALUES` block.

Errors: the ASK helper on a non-ASK response → `{TCLUTILS TUSPARQL NOTASK}`;
transport/HTTP errors propagate from `tufetch`. The flattening / ASK / URL logic
is verified on Tcl 8.6 and 9.x, and a live `query.wikidata.org` round-trip was
confirmed.
