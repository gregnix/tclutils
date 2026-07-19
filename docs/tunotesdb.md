# tclutils::tunotesdb — SQLite-backed note store

The persistent counterpart to [`tunotes`](tunotes.md). Same note layout, so both
engines are interchangeable and `tkutils::tkunotes` works with either.

```tcl
package require sqlite3
package require tclutils::tunotesdb 0.1

sqlite3 db notes.db
tclutils::tunotesdb::init db

set id [tclutils::tunotesdb::create db "Build notes" "litehtml with nmake" {build}]
foreach hit [tclutils::tunotesdb::search db nmake] {
    puts "[dict get $hit title]: [dict get $hit snippet]"
}
```

## Which of the two engines

| | `tunotes` | `tunotesdb` |
|---|---|---|
| Storage | one Tcl dict, saved as JSON | one row per note in SQLite |
| Saving | rewrites the whole file | transactional, per note |
| Search | linear `string match` | FTS5 index, ranked, with snippets |
| Hierarchy | walked in Tcl | `WITH RECURSIVE` in the database |
| Dependencies | none | `sqlite3` (FTS5) |
| Good for | a handful of notes, no extra packages | many notes, several writers, a server |

The note dict is identical in both:

```tcl
id parent_id title content created modified tags
```

`parent_id` is the empty string for a root note; `tags` is a Tcl list;
timestamps are `%Y-%m-%d %H:%M:%S`, as in `tunotes`.

## Opening the database

Like [`tusqlite`](tusqlite.md), this module does **not** `package require
sqlite3` itself — the caller opens the database and passes the handle. That
keeps the module sourceable anywhere and leaves the choice of file, flags and
lifetime with the application.

### `init db`

Creates the schema if it is not there yet and switches the database to WAL, so
readers do not block the writer. Safe to call on every start.

The full-text index is an FTS5 table with `content='notes'`: it does not store
the text a second time, and three triggers keep it in step with the table — no
application code has to remember to reindex. `init` raises `NOFTS5` if the
SQLite build has no FTS5 (part of the standard build since 3.9).

## Commands

All commands are also reachable through the ensemble `tclutils::tunotesdb`.

### Notes

| Command | Returns |
|---|---|
| `create db title content ?tags? ?parentId?` | the new id |
| `update db id title content ?tags? ?parentId?` | the id; `parentId` defaults to `KEEP` |
| `get db id` | the note dict |
| `exists db id` | boolean |
| `delete db id ?cascade?` | —; with `cascade` (default 1) the subtree goes, without it the children become roots |
| `move db id newParentId` | the id; refuses cycles |
| `ids db` / `count db` | all ids / how many |

### Hierarchy

| Command | Returns |
|---|---|
| `roots db` | ids without a parent |
| `children db parentId` | direct children (`""` for the roots) |
| `descendants db id` | everything below, depth-first |
| `ancestors db id` | from the parent up to the root |
| `parent db id` | the parent id, `""` for a root |
| `path db id` | root first, the note itself last |
| `depth db id` | 0 for a root |
| `siblings db id` | the other children of the same parent |
| `subtree db id` | the note plus everything below |

The tree lives in `parent_id` and is walked with `WITH RECURSIVE`. The work
stays in the database instead of loading every note to follow a chain of
parents.

### Search

```tcl
search db query ?-limit N? ?-snippet N?
```

Returns a list of dicts with the keys `id`, `title`, `snippet` and `rank`, best
match first. `-limit` defaults to 50 (`0` for all), `-snippet` to 10 words of
context.

The query goes to FTS5, so its syntax applies:

| Query | Meaning |
|---|---|
| `nmake` | the word |
| `alpha beta` | both words (AND) |
| `"exact phrase"` | literally |
| `config*` | prefix |
| `alpha OR beta`, `alpha NOT beta` | as written |

A syntactically wrong query raises `BADQUERY` rather than returning nothing —
a typo should not look like an empty result.

### Tags

`byTag db tag` returns the ids carrying the tag, `tags db` every tag in use,
sorted and without duplicates. Tags are stored as a Tcl list in one column and
compared in Tcl, so a tag containing a space stays one tag.

### Bridge to tunotes

| Command | Purpose |
|---|---|
| `toStore db` | the whole database as a `tunotes` store |
| `fromStore db store ?-clear 1?` | import a `tunotes` store; returns how many notes |

`toStore` hands the data to code that expects the in-memory engine — including
`tclutils::tunotes::toJson` for a JSON export. `fromStore` runs in one
transaction: a failure half-way leaves the database as it was.

## Errors

`errorCode` is always `{TCLUTILS TUNOTESDB <REASON>}`:

| Reason | When |
|---|---|
| `NODB` | the handle is not a usable sqlite3 command |
| `NOFTS5` | SQLite without FTS5 |
| `NOTFOUND` | no note with that id, or no such parent |
| `CYCLE` | a move would put a note under itself or a descendant |
| `BADQUERY` | FTS5 could not parse the search query |
| `BADOPTION` | unknown option, or an unusable `-limit` |
| `BADNOTE` | a note handed to `fromStore` is missing a field |

## Requirements

Tcl 8.6 or later, `tclutils::tusqlite`, and an `sqlite3` package with FTS5 at
the point of use. Tested against SQLite 3.45 (Tcl 8.6) and 3.53 (Tcl 9.0).
