# tclutils::tusqlite

Small, NULL-safe helpers over an existing `sqlite3` database handle. The module
does **not** `package require sqlite3` itself — you pass it a handle you opened —
so it loads anywhere, and only the calls that actually touch the database need
the package present.

Why it exists: in `db eval {INSERT ... VALUES(:x)}` the placeholder `:x` binds to
the Tcl **variable `x` in scope**, not to anything passed as an argument — a value
you meant to pass as a dict silently becomes `NULL`. And an *omitted* bind
variable yields SQL `NULL`, while a set-but-empty one yields `''`. `insert` hides
both traps.

## API

```tcl
sqlite3 db mydata.db
::tclutils::tusqlite::insert db people {name Alice age 30}   ;# -> new rowid
::tclutils::tusqlite::insert db people {name Bob}            ;# age omitted -> NULL
::tclutils::tusqlite::insert db people \
    [list name Carol age [::tclutils::tusqlite::null]]       ;# explicit NULL
foreach row [::tclutils::tusqlite::rows db {SELECT name, age FROM people}] {
    puts [dict get $row name]
}
set n [::tclutils::tusqlite::value db {SELECT count(*) FROM people} 0]
```

Commands:

- `insert db table dict` — INSERT a row from a column→value dict; returns the new
  rowid. A missing key, or a value equal to `[null]`, is stored as SQL `NULL`; an
  empty string stays `''`. Identifiers are quoted, so reserved words and spaces
  in column names work.
- `rows db sql ?params?` — run a query, return a list of column→value dicts
  (empty list if there are no rows).
- `value db sql ?-default d? ?-params dict?` — the first column of the first
  row, or the default (`""`) when there is no row. The options keep a
  parameter dict apart from the default; the positional forms
  `value db sql default` and `value db sql default params` still work
  (0.2). Errors `{TCLUTILS TUSQLITE OPTION}`.
- `update db table set where` — UPDATE the rows matching every key/value of
  `where` with the columns in `set`; returns the number of changed rows.
- `delete db table where` — DELETE the matching rows; returns their number.

`params` is a dict that binds `:name` placeholders; caller variables are not
visible to the query. A value equal to `[null]` binds SQL `NULL`. In `where`,
`[null]` becomes `IS NULL`. An empty `where` is refused, so a typo cannot
change or delete every row.

```tcl
set r [::tclutils::tusqlite::rows db {SELECT * FROM people WHERE age > :a} {a 20}]
::tclutils::tusqlite::update db people {age 31} {name Alice}
::tclutils::tusqlite::delete db people {name Bob}
```
- `quoteId name` — quote an SQL identifier (wrap in double quotes, doubling any
  embedded ones).
- `null` — the sentinel value that `insert` maps to SQL `NULL`.

Errors: an empty insert or set dict → `{TCLUTILS TUSQLITE EMPTY}`; an empty
where dict → `{TCLUTILS TUSQLITE WHERE}`; a bad parameter name →
`{TCLUTILS TUSQLITE PARAM <name>}`. Verified on Tcl 8.6
(sqlite3 3.45); loads on 9.x (the database-backed calls need an sqlite3 build for
that version).
