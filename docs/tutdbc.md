# tclutils::tutdbc

Small, NULL-safe helpers over an existing **TDBC** connection object — the tdbc
analogue of `tclutils::tusqlite`. The module does **not** `package require` any
tdbc driver itself — you pass it a connection you opened — so it loads anywhere,
and only the calls that actually touch the database need a driver present.

Why it exists: TDBC has two quiet traps. `allrows -as dicts` silently **drops
NULL columns** from a row dict, so a `SELECT a, b` where `b` is NULL comes back
as just `{a ...}` — the column vanishes instead of reading as `""`. And a bind
dict that is **missing a key** binds SQL `NULL` for that column. On top of that,
tdbc::sqlite3's incremental `nextrow`/`nextlist`/`nextdict` cursor returns **no
rows at all** for FTS5 / virtual-table queries. `rows` and `insert` hide all
three: `rows` builds dicts from `allrows` (which works for FTS too) and re-pads
NULL columns from `$rs columns`, and `insert` maps a missing/`[null]` value to
SQL `NULL` on purpose while keeping a real `0` as `0`.

## API

```tcl
tdbc::sqlite3::connection create db mydata.db
::tclutils::tutdbc::insert db people {name Alice age 30}     ;# -> affected rows
::tclutils::tutdbc::insert db people {name Bob}              ;# age omitted -> NULL
::tclutils::tutdbc::insert db people \
    [list name Carol age [::tclutils::tutdbc::null]]         ;# explicit NULL
foreach row [::tclutils::tutdbc::rows db \
        {SELECT name, age FROM people WHERE age > :min} {min 18}] {
    puts [dict get $row name]
}
set n [::tclutils::tutdbc::value db {SELECT count(*) FROM people} {} 0]
::tclutils::tutdbc::execute db {UPDATE people SET age=:a WHERE name=:n} {a 31 n Bob}
::tclutils::tutdbc::transaction db {
    ::tclutils::tutdbc::insert db people {name Dave}
    ::tclutils::tutdbc::insert db people {name Erin}
}
```

Bind parameters are `:name` in the SQL and supplied as a dict as the (optional)
last argument, e.g. `{min 18}` above.

Commands:

- `rows conn sql ?binds?` — run a query, return a list of column→value dicts, in
  row order (empty list if there are no rows). NULL-safe: a NULL cell reads as
  `""` and its column stays. Works for FTS5 / virtual-table queries, where the
  incremental cursor would return nothing.
- `value conn sql ?binds? ?default?` — the first column of the first row, or
  `default` (default empty string) if the result is empty.
- `execute conn sql ?binds?` — run a non-query statement (INSERT/UPDATE/DELETE/
  DDL); returns the affected-row count.
- `insert conn table dict` — INSERT a row from a column→value dict; returns the
  affected-row count. A missing key, or a value equal to `[null]`, is stored as
  SQL `NULL`; a real `0` is stored as `0`. Identifiers are quoted, so reserved
  words and spaces in column names work. For a generated key use a `RETURNING`
  clause via `rows`/`execute` (backend-specific).
- `transaction conn script` — run `script` in a transaction; commit on success,
  roll back and re-raise on error. The script runs in the caller's scope and its
  value is returned.
- `quoteId name` — quote an SQL identifier (wrap in double quotes, doubling any
  embedded ones).
- `null` — the sentinel value that `insert` maps to SQL `NULL`.

Errors: an empty insert dict → `{TCLUTILS TUTDBC EMPTY}`. Verified on Tcl 8.6.14
and 9.0.2 with `tdbc::sqlite3` (including FTS5); the same shape works for
`tdbc::postgres` and other drivers, which need to be present for the calls that
touch the database.

See also: `tclutils::tusqlite` (the same idea over a native `sqlite3` handle).
