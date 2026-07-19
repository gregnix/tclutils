# tunotesdb-0.1.tm -- SQLite-backed note store
# Description: SQLite-backed note store with full-text search
# Category: Data · structures & formats
#
# Copyright (c) 2026 Gregor Cramer (gregnix)
# MIT licensed.
#
# The persistent counterpart to tclutils::tunotes. Same note layout -- a dict
# with the fields
#
#     id parent_id title content created modified tags
#
# -- so both engines are interchangeable and tkutils::tkunotes works with
# either. What differs is where the data lives and what that makes possible:
#
#   tunotes      the whole collection is one Tcl dict, saved as JSON. Simple
#                and dependency-free; every save rewrites the whole file, and
#                search is a linear string match.
#   tunotesdb    one row per note in SQLite. Changes are transactional, the
#                hierarchy is queried with WITH RECURSIVE, and search goes
#                through an FTS5 index with ranking and snippets.
#
# For a handful of notes tunotes is the better fit. For a server, for several
# writers, or for more text than fits comfortably in memory, this one is.
#
# Bridging both directions is one call: `toStore` returns a tunotes dict,
# `fromStore` imports one.
#
# Like tclutils::tusqlite this module deliberately does NOT `package require
# sqlite3` itself -- the caller opens the database and passes the handle:
#
#     package require sqlite3
#     package require tclutils::tunotesdb
#     sqlite3 db notes.db
#     tclutils::tunotesdb::init db
#     set id [tclutils::tunotesdb::create db "Title" "Text" {tag1 tag2}]
#
# Errors use errorCode {TCLUTILS TUNOTESDB <REASON>}.
#
# Tcl 8.6+ and 9.x. Needs SQLite with FTS5 (part of the standard build since
# 3.9); init reports plainly if it is missing.

package require Tcl 8.6-
package require tclutils::tusqlite 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tunotesdb {
    namespace export init create update get exists delete move \
        roots children descendants ancestors parent path depth siblings \
        subtree search byTag tags ids count toStore fromStore
    namespace ensemble create
}

# _throw --
#   Raise an error with the module's errorCode convention.
proc ::tclutils::tunotesdb::_throw {reason message} {
    return -code error -errorcode [list TCLUTILS TUNOTESDB $reason] $message
}

# _now --
#   Timestamp in the format tunotes uses, so both engines stay comparable.
proc ::tclutils::tunotesdb::_now {} {
    return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
}

# _require --
#   Fail unless the note exists.
proc ::tclutils::tunotesdb::_require {db id} {
    if {![exists $db $id]} {
        _throw NOTFOUND "Note not found: $id"
    }
}

# _dbId --
#   The dict uses "" for "no parent", SQL uses NULL. Translate towards SQL.
proc ::tclutils::tunotesdb::_dbId {id} {
    if {$id eq ""} {
        return [::tclutils::tusqlite::null]
    }
    return $id
}

# _row2note --
#   Turn a result row (dict from db eval -array style) into a note dict.
proc ::tclutils::tunotesdb::_row2note {row} {
    set parent [dict get $row parent_id]
    if {$parent eq "" || $parent eq "NULL"} { set parent "" }
    return [dict create \
        id        [dict get $row id] \
        parent_id $parent \
        title     [dict get $row title] \
        content   [dict get $row content] \
        created   [dict get $row created] \
        modified  [dict get $row modified] \
        tags      [dict get $row tags]]
}

# init --
#   Create the schema if it is not there yet, and switch the database to WAL
#   so readers do not block the writer. Safe to call on every start.
#
#   The FTS5 table is an external-content index (content='notes'): it does not
#   store the text a second time, and three triggers keep it in step with the
#   table -- no application code has to remember to reindex.
proc ::tclutils::tunotesdb::init {db} {
    if {[catch {$db eval {SELECT 1}} message]} {
        _throw NODB "not a usable sqlite3 handle: $message"
    }

    $db eval {
        CREATE TABLE IF NOT EXISTS notes (
            id        INTEGER PRIMARY KEY,
            parent_id INTEGER REFERENCES notes(id) ON DELETE CASCADE,
            title     TEXT NOT NULL DEFAULT '',
            content   TEXT NOT NULL DEFAULT '',
            created   TEXT NOT NULL,
            modified  TEXT NOT NULL,
            tags      TEXT NOT NULL DEFAULT ''
        );
        CREATE INDEX IF NOT EXISTS notes_parent ON notes(parent_id);
    }

    if {[catch {
        $db eval {
            CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
                title, content,
                content='notes', content_rowid='id',
                tokenize='unicode61 remove_diacritics 2'
            );
        }
    } message]} {
        _throw NOFTS5 "SQLite without FTS5 support: $message"
    }

    $db eval {
        CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
            INSERT INTO notes_fts(rowid, title, content)
            VALUES (new.id, new.title, new.content);
        END;
        CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
            INSERT INTO notes_fts(notes_fts, rowid, title, content)
            VALUES ('delete', old.id, old.title, old.content);
            INSERT INTO notes_fts(rowid, title, content)
            VALUES (new.id, new.title, new.content);
        END;
        CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
            INSERT INTO notes_fts(notes_fts, rowid, title, content)
            VALUES ('delete', old.id, old.title, old.content);
        END;
    }

    # Readers alongside a writer; without this a single writer blocks everyone.
    catch {$db eval {PRAGMA journal_mode = WAL}}
    # Deleting a parent must take its children with it (see delete).
    catch {$db eval {PRAGMA foreign_keys = ON}}
    return
}

# create --
#   Insert a note and return its id. The id is derived from the clock, exactly
#   as tunotes does, so ids stay comparable between the two engines.
proc ::tclutils::tunotesdb::create {db title content {tagList {}} {parentId ""}} {
    if {$parentId ne "" && ![exists $db $parentId]} {
        _throw NOTFOUND "Parent note not found: $parentId"
    }
    set id [clock microseconds]
    while {[exists $db $id]} { incr id }
    set ts [_now]
    ::tclutils::tusqlite::insert $db notes [dict create \
        id        $id \
        parent_id [_dbId $parentId] \
        title     $title \
        content   $content \
        created   $ts \
        modified  $ts \
        tags      $tagList]
    return $id
}

# update --
#   Replace title, content and tags; parentId defaults to KEEP, as in tunotes.
proc ::tclutils::tunotesdb::update {db id title content {tagList {}} {parentId KEEP}} {
    _require $db $id
    set ts [_now]
    if {$parentId eq "KEEP"} {
        $db eval {
            UPDATE notes SET title = $title, content = $content,
                             tags = $tagList, modified = $ts
            WHERE id = $id
        }
    } else {
        if {$parentId ne "" && ![exists $db $parentId]} {
            _throw NOTFOUND "Parent note not found: $parentId"
        }
        set p [_dbId $parentId]
        $db eval {
            UPDATE notes SET title = $title, content = $content,
                             tags = $tagList, modified = $ts, parent_id = $p
            WHERE id = $id
        }
    }
    return $id
}

# get --
#   The note as a dict, in the tunotes layout.
proc ::tclutils::tunotesdb::get {db id} {
    _require $db $id
    $db eval {
        SELECT id, IFNULL(parent_id,'') AS parent_id, title, content,
               created, modified, tags
        FROM notes WHERE id = $id
    } row {
        return [_row2note [array get row]]
    }
    _throw NOTFOUND "Note not found: $id"
}

proc ::tclutils::tunotesdb::exists {db id} {
    return [expr {[$db eval {SELECT COUNT(*) FROM notes WHERE id = $id}] > 0}]
}

# delete --
#   With cascade (the default) the whole subtree goes; without it the children
#   become roots -- the same choice tunotes offers.
proc ::tclutils::tunotesdb::delete {db id {cascade 1}} {
    _require $db $id
    $db transaction {
        if {$cascade} {
            foreach childId [children $db $id] {
                delete $db $childId 1
            }
        } else {
            $db eval {UPDATE notes SET parent_id = NULL WHERE parent_id = $id}
        }
        $db eval {DELETE FROM notes WHERE id = $id}
    }
    return
}

# move --
#   Re-parent a note. Refuses to move a note under itself or one of its own
#   descendants, which would cut a loop out of the tree.
proc ::tclutils::tunotesdb::move {db id newParentId} {
    _require $db $id
    if {$newParentId ne "" && ![exists $db $newParentId]} {
        _throw NOTFOUND "Parent note not found: $newParentId"
    }
    if {$newParentId eq $id || $newParentId in [descendants $db $id]} {
        _throw CYCLE "Cannot move a note under itself or a descendant"
    }
    set p [_dbId $newParentId]
    set ts [_now]
    $db eval {UPDATE notes SET parent_id = $p, modified = $ts WHERE id = $id}
    return $id
}

# --- hierarchy ------------------------------------------------------------
#
# The tree lives in parent_id, and SQLite walks it with WITH RECURSIVE. That
# keeps the work in the database instead of loading every note to follow a
# chain of parents.

proc ::tclutils::tunotesdb::roots {db} {
    return [$db eval {SELECT id FROM notes WHERE parent_id IS NULL ORDER BY id}]
}

proc ::tclutils::tunotesdb::children {db parentId} {
    if {$parentId eq ""} {
        return [roots $db]
    }
    return [$db eval {SELECT id FROM notes WHERE parent_id = $parentId ORDER BY id}]
}

# descendants --
#   Every note below this one, depth-first.
proc ::tclutils::tunotesdb::descendants {db id} {
    return [$db eval {
        WITH RECURSIVE sub(id, depth) AS (
            SELECT id, 0 FROM notes WHERE parent_id = $id
            UNION ALL
            SELECT n.id, sub.depth + 1
            FROM notes n JOIN sub ON n.parent_id = sub.id
        )
        SELECT id FROM sub
    }]
}

# ancestors --
#   From the direct parent up to the root.
proc ::tclutils::tunotesdb::ancestors {db id} {
    _require $db $id
    return [$db eval {
        WITH RECURSIVE up(id, parent_id, lvl) AS (
            SELECT id, parent_id, 0 FROM notes WHERE id = $id
            UNION ALL
            SELECT n.id, n.parent_id, up.lvl + 1
            FROM notes n JOIN up ON n.id = up.parent_id
        )
        SELECT id FROM up WHERE lvl > 0 ORDER BY lvl
    }]
}

proc ::tclutils::tunotesdb::parent {db id} {
    _require $db $id
    return [$db eval {SELECT IFNULL(parent_id,'') FROM notes WHERE id = $id}]
}

# path --
#   Root first, the note itself last -- the same order tunotes returns.
proc ::tclutils::tunotesdb::path {db id} {
    _require $db $id
    set out [ancestors $db $id]
    set acc {}
    foreach a $out { set acc [linsert $acc 0 $a] }
    lappend acc $id
    return $acc
}

proc ::tclutils::tunotesdb::depth {db id} {
    _require $db $id
    return [llength [ancestors $db $id]]
}

proc ::tclutils::tunotesdb::siblings {db id} {
    _require $db $id
    set p [parent $db $id]
    set out {}
    foreach c [children $db $p] {
        if {$c ne $id} { lappend out $c }
    }
    return $out
}

# subtree --
#   The note itself plus everything below it.
proc ::tclutils::tunotesdb::subtree {db id} {
    _require $db $id
    return [linsert [descendants $db $id] 0 $id]
}

# --- search ---------------------------------------------------------------

# search --
#   Full-text search over title and content. Returns a list of dicts with the
#   keys id, title, snippet and rank, best match first.
#
#   The query goes to FTS5, so its syntax applies: several words mean AND,
#   "quoted phrases" match literally, `word*` is a prefix search, OR and NOT
#   work as written. A syntactically wrong query raises BADQUERY rather than
#   returning nothing, so a typo does not look like an empty result.
#
#   -limit N    at most N hits (default 50, 0 for all)
#   -snippet N  words of context per hit (default 10)
proc ::tclutils::tunotesdb::search {db query args} {
    set limit 50
    set words 10
    foreach {option value} $args {
        switch -- $option {
            -limit   { set limit $value }
            -snippet { set words $value }
            default  { _throw BADOPTION "unknown option: $option" }
        }
    }
    if {![string is integer -strict $limit] || $limit < 0} {
        _throw BADOPTION "-limit must be a non-negative integer, got: $limit"
    }
    if {$limit == 0} { set limit -1 }

    set out {}
    if {[catch {
        $db eval {
            SELECT n.id AS id, n.title AS title,
                   snippet(notes_fts, 1, '[', ']', '...', $words) AS snip,
                   rank AS rnk
            FROM notes_fts JOIN notes n ON n.id = notes_fts.rowid
            WHERE notes_fts MATCH $query
            ORDER BY rank
            LIMIT $limit
        } row {
            lappend out [dict create \
                id      $row(id) \
                title   $row(title) \
                snippet $row(snip) \
                rank    $row(rnk)]
        }
    } message]} {
        _throw BADQUERY "cannot run the query \"$query\": $message"
    }
    return $out
}

# byTag --
#   Ids of all notes carrying the tag. Tags are a Tcl list in one column, so
#   the filtering happens in Tcl -- exact, and independent of how the list was
#   quoted.
proc ::tclutils::tunotesdb::byTag {db tag} {
    set out {}
    $db eval {SELECT id, tags FROM notes ORDER BY id} row {
        if {$tag in $row(tags)} { lappend out $row(id) }
    }
    return $out
}

# tags --
#   Every tag in use, sorted, without duplicates.
proc ::tclutils::tunotesdb::tags {db} {
    set seen {}
    $db eval {SELECT tags FROM notes} row {
        foreach t $row(tags) { dict set seen $t 1 }
    }
    return [lsort [dict keys $seen]]
}

proc ::tclutils::tunotesdb::ids {db} {
    return [$db eval {SELECT id FROM notes ORDER BY id}]
}

proc ::tclutils::tunotesdb::count {db} {
    return [$db eval {SELECT COUNT(*) FROM notes}]
}

# --- bridge to tunotes ----------------------------------------------------

# toStore --
#   The whole database as a tunotes store (id -> note dict). Useful to hand
#   the data to code that expects the in-memory engine, or to export as JSON
#   through tclutils::tunotes::toJson.
proc ::tclutils::tunotesdb::toStore {db} {
    set store [dict create]
    $db eval {
        SELECT id, IFNULL(parent_id,'') AS parent_id, title, content,
               created, modified, tags
        FROM notes ORDER BY id
    } row {
        dict set store $row(id) [_row2note [array get row]]
    }
    return $store
}

# fromStore --
#   Import a tunotes store. Existing notes with the same id are replaced;
#   everything happens in one transaction, so a failure half-way leaves the
#   database as it was.
#
#   -clear 1   empty the table first
proc ::tclutils::tunotesdb::fromStore {db store args} {
    set clear 0
    foreach {option value} $args {
        switch -- $option {
            -clear  { set clear $value }
            default { _throw BADOPTION "unknown option: $option" }
        }
    }
    $db transaction {
        if {$clear} { $db eval {DELETE FROM notes} }
        dict for {id note} $store {
            foreach field {parent_id title content created modified tags} {
                if {![dict exists $note $field]} {
                    _throw BADNOTE "note $id has no field \"$field\""
                }
            }
            set parent   [dict get $note parent_id]
            set title    [dict get $note title]
            set content  [dict get $note content]
            set created  [dict get $note created]
            set modified [dict get $note modified]
            set tagList  [dict get $note tags]
            $db eval {DELETE FROM notes WHERE id = $id}
            ::tclutils::tusqlite::insert $db notes [dict create \
                id        $id \
                parent_id [_dbId $parent] \
                title     $title \
                content   $content \
                created   $created \
                modified  $modified \
                tags      $tagList]
        }
    }
    return [dict size $store]
}

package provide tclutils::tunotesdb 0.1
