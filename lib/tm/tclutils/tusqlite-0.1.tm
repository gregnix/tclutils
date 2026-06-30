# tclutils::tusqlite -- thin, safe helpers over an existing sqlite3 db command.
# Description: thin, safe helpers over an existing sqlite3 db command.
# Category: Data · structures & formats
# Tcl 8.6+ and 9.x.
#
# Works on a db handle the caller already opened (e.g. `sqlite3 db file.db`); the
# module deliberately does NOT `package require sqlite3` itself, so it can be
# sourced anywhere and only needs the package at the point of use.
#
# The point of this module is to avoid the classic sqlite3-Tcl binding trap:
# `db eval {... :x ...}` binds :x to a *Tcl variable in scope*, not to anything
# you pass alongside. insert builds the statement and binds values in an
# isolated scope, and -- crucially -- a missing/NULL value is bound as SQL NULL
# (by leaving the bind variable unset), not as an empty string.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tusqlite {
    namespace export insert rows value quoteId null
    variable version 0.1
    variable NULLVAL "\u0000TUSQLITE-NULL\u0000"
}

# null -- sentinel meaning "bind SQL NULL" for a value in an insert dict.
proc ::tclutils::tusqlite::null {} {
    variable NULLVAL
    return $NULLVAL
}

# quoteId name -- quote an SQL identifier (table/column).
proc ::tclutils::tusqlite::quoteId {name} {
    return "\"[string map [list \" \"\"] $name]\""
}

# insert db table dict -- INSERT one row. Keys are column names, values the data.
# A column whose value equals [tusqlite::null] (or that is simply omitted from
# the dict) is stored as SQL NULL. Returns the new rowid.
proc ::tclutils::tusqlite::insert {db table data} {
    variable NULLVAL
    if {[dict size $data] == 0} {
        return -code error -errorcode {TCLUTILS TUSQLITE EMPTY} \
            "insert needs at least one column"
    }
    set cols {}
    set phs  {}
    set vals {}
    set i 0
    dict for {k v} $data {
        lappend cols [quoteId $k]
        lappend phs  ":c$i"
        lappend vals $v
        incr i
    }
    set sql "INSERT INTO [quoteId $table] ([join $cols ,]) VALUES ([join $phs ,])"
    return [apply [list {db sql vals nullv} {
        set i 0
        foreach v $vals {
            if {$v ne $nullv} { set c$i $v }   ;# leave unset -> binds SQL NULL
            incr i
        }
        $db eval $sql
        return [$db last_insert_rowid]
    }] $db $sql $vals $NULLVAL]
}

# rows db sql -- run a query, return a list of dicts (column -> value), in order.
proc ::tclutils::tusqlite::rows {db sql} {
    set out [list]
    $db eval $sql row {
        set d [dict create]
        foreach col $row(*) { dict set d $col $row($col) }
        lappend out $d
    }
    return $out
}

# value db sql ?default? -- first column of the first row, or default if empty.
proc ::tclutils::tusqlite::value {db sql {default ""}} {
    set rs [rows $db $sql]
    if {[llength $rs] == 0} { return $default }
    return [lindex [dict values [lindex $rs 0]] 0]
}

package provide tclutils::tusqlite 0.1
