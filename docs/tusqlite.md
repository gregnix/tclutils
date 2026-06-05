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
- `rows db sql` — run a query, return a list of column→value dicts (empty list if
  there are no rows).
- `value db sql ?default?` — the first column of the first row, or `default`
  (default empty string) if the result is empty.
- `quoteId name` — quote an SQL identifier (wrap in double quotes, doubling any
  embedded ones).
- `null` — the sentinel value that `insert` maps to SQL `NULL`.

Errors: an empty insert dict → `{TCLUTILS TUSQLITE EMPTY}`. Verified on Tcl 8.6
(sqlite3 3.45); loads on 9.x (the database-backed calls need an sqlite3 build for
that version).
