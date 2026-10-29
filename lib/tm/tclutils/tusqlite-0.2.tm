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
#
# rows and value take an optional params dict: its keys become the bind
# variables of the query (`:id` or `$id`), set in an isolated scope, so
#   tusqlite::rows db {SELECT * FROM t WHERE id = :id} {id 4711}
# binds 4711 safely -- without building SQL text from the value. update and
# delete build their WHERE clause from a dict the same way.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tusqlite {
    namespace export insert rows value update delete quoteId null
    variable version 0.2
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

# Run $sql with the keys of $params as bind variables in an isolated scope.
# Values equal to [null] stay unset (bind SQL NULL). Returns a list of dicts.
proc ::tclutils::tusqlite::_query {db sql params} {
    variable NULLVAL
    dict for {k v} $params {
        if {![regexp {^[A-Za-z][A-Za-z0-9_]*$} $k]} {
            return -code error -errorcode [list TCLUTILS TUSQLITE PARAM $k] \
                "bad parameter name \"$k\": letters, digits and _ only"
        }
    }
    return [apply [list {__db __sql __params __nullv} {
        dict for {__k __v} $__params {
            if {$__v ne $__nullv} { set $__k $__v }
        }
        set __out [list]
        $__db eval $__sql __row {
            set __d [dict create]
            foreach __c $__row(*) { dict set __d $__c $__row($__c) }
            lappend __out $__d
        }
        return $__out
    }] $db $sql $params $NULLVAL]
}

# rows db sql ?params? -- run a query, return a list of dicts (column ->
# value), in order. params: dict of bind variables (see header).
proc ::tclutils::tusqlite::rows {db sql {params {}}} {
    return [_query $db $sql $params]
}

# value db sql ?-default d? ?-params dict? -- first column of the first row,
# or the default if the query returns no row. The positional forms
# "value db sql default" and "value db sql default params" still work;
# with the options a parameter dict can no longer be taken for the default
# ("value db $sql {id 1}" returned the dict when no row matched).
proc ::tclutils::tusqlite::value {db sql args} {
    set default ""
    set params {}
    if {[llength $args] && [lindex $args 0] in {-default -params}} {
        if {[llength $args] % 2} {
            return -code error -errorcode {TCLUTILS TUSQLITE OPTION} \
                "option \"[lindex $args end]\" requires a value"
        }
        foreach {k v} $args {
            switch -- $k {
                -default { set default $v }
                -params  { set params $v }
                default {
                    return -code error -errorcode {TCLUTILS TUSQLITE OPTION} \
                        "unknown option \"$k\": must be -default or -params"
                }
            }
        }
    } elseif {[llength $args] > 2} {
        return -code error -errorcode {TCLUTILS TUSQLITE OPTION} \
            "wrong # args: should be \"value db sql ?-default d? ?-params dict?\""
    } else {
        lassign $args default params
    }
    set rs [_query $db $sql $params]
    if {[llength $rs] == 0} { return $default }
    return [lindex [dict values [lindex $rs 0]] 0]
}

# WHERE clause "a = :w0 AND b = :w1" plus its params; [null] -> IS NULL.
proc ::tclutils::tusqlite::_where {where} {
    variable NULLVAL
    if {[dict size $where] == 0} {
        return -code error -errorcode {TCLUTILS TUSQLITE WHERE} \
            "a WHERE dict is required (refusing to touch every row)"
    }
    set parts {}; set params {}; set i 0
    dict for {k v} $where {
        if {$v eq $NULLVAL} {
            lappend parts "[quoteId $k] IS NULL"
        } else {
            lappend parts "[quoteId $k] = :w$i"
            dict set params w$i $v
        }
        incr i
    }
    return [list [join $parts " AND "] $params]
}

# update db table set where -- UPDATE the rows matching all key/value pairs
# of the where dict with the columns of the set dict. [null] in set stores
# NULL. Returns the number of changed rows.
proc ::tclutils::tusqlite::update {db table set where} {
    if {[dict size $set] == 0} {
        return -code error -errorcode {TCLUTILS TUSQLITE EMPTY} \
            "update needs at least one column"
    }
    lassign [_where $where] wsql params
    set cols {}; set i 0
    dict for {k v} $set {
        lappend cols "[quoteId $k] = :s$i"
        dict set params s$i $v
        incr i
    }
    _query $db "UPDATE [quoteId $table] SET [join $cols ,] WHERE $wsql" $params
    return [$db changes]
}

# delete db table where -- DELETE the rows matching the where dict. Returns
# the number of deleted rows.
proc ::tclutils::tusqlite::delete {db table where} {
    lassign [_where $where] wsql params
    _query $db "DELETE FROM [quoteId $table] WHERE $wsql" $params
    return [$db changes]
}

package provide tclutils::tusqlite 0.2
