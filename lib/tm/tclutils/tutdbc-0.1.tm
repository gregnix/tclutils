# tclutils::tutdbc -- thin, NULL-safe helpers over an existing TDBC connection.
# Description: thin, NULL-safe helpers over an existing tdbc connection object.
# Category: Data · structures & formats
# Tcl 8.6+ and 9.x.
#
# The TDBC analogue of tclutils::tusqlite. Works on a connection the caller
# already opened (e.g. `tdbc::sqlite3::connection create db file.db`); the module
# does NOT require any tdbc driver itself, so it can be sourced anywhere and only
# needs a driver at the point of use.
#
# It papers over the two well-known TDBC traps:
#   * `allrows -as dicts` silently DROPS NULL columns from a row dict.  rows/value
#     build dicts from `$rs columns` + `$rs nextlist`, so every column survives
#     and NULL comes back as an empty string, correctly aligned.
#   * a bind dict missing a key binds SQL NULL for that column.  insert exploits
#     this on purpose: a value equal to [tutdbc::null] (or omitted) is stored as
#     SQL NULL, not "".
#
# Bind parameters are `:name` in the SQL and supplied as a dict, e.g.
#     tutdbc::rows $c {SELECT * FROM t WHERE id=:id} [dict create id 5]

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tutdbc {
    namespace export rows value execute insert transaction quoteId null
    variable version 0.1
    variable NULLVAL "\u0000TUTDBC-NULL\u0000"
}

# null -- sentinel meaning "bind SQL NULL" for a value in an insert dict.
proc ::tclutils::tutdbc::null {} {
    variable NULLVAL
    return $NULLVAL
}

# quoteId name -- quote an SQL identifier (table/column).
proc ::tclutils::tutdbc::quoteId {name} {
    return "\"[string map [list \" \"\"] $name]\""
}

# rows conn sql ?binds? -- run a query, return a list of dicts (column -> value)
# in row order. NULL-safe: a NULL cell is the empty string and the column stays.
#
# Uses `allrows -as dicts` (which, unlike the incremental nextlist cursor, also
# works for FTS5 / virtual-table queries in tdbc::sqlite3) and re-adds any NULL
# column it drops, using `$rs columns` as the authoritative column set. For an
# FTS/virtual result `columns` is empty; there the dicts are taken as-is (such
# results have no NULL columns in practice).
proc ::tclutils::tutdbc::rows {conn sql {binds {}}} {
    set out [list]
    set stmt [$conn prepare $sql]
    try {
        set rs [expr {[dict size $binds] ? [$stmt execute $binds] : [$stmt execute]}]
        try {
            set cols [$rs columns]
            foreach r [$rs allrows -as dicts] {
                if {[llength $cols]} {
                    set d [dict create]
                    foreach c $cols {
                        dict set d $c [expr {[dict exists $r $c] ? [dict get $r $c] : ""}]
                    }
                    lappend out $d
                } else {
                    lappend out $r
                }
            }
        } finally {
            catch {$rs close}
        }
    } finally {
        catch {$stmt close}
    }
    return $out
}

# value conn sql ?binds? ?default? -- first column of the first row, else default.
proc ::tclutils::tutdbc::value {conn sql {binds {}} {default ""}} {
    set rs [rows $conn $sql $binds]
    if {[llength $rs] == 0} { return $default }
    return [lindex [dict values [lindex $rs 0]] 0]
}

# execute conn sql ?binds? -- run a non-query statement, return affected rows.
proc ::tclutils::tutdbc::execute {conn sql {binds {}}} {
    set n 0
    set stmt [$conn prepare $sql]
    try {
        set rs [expr {[dict size $binds] ? [$stmt execute $binds] : [$stmt execute]}]
        catch {set n [$rs rowcount]}
        catch {$rs close}
    } finally {
        catch {$stmt close}
    }
    if {![string is integer -strict $n] || $n < 0} { set n 0 }
    return $n
}

# insert conn table dict -- INSERT one row. Keys are column names. A value equal
# to [tutdbc::null] (or a key omitted from the dict) is stored as SQL NULL.
# Returns the affected-row count (1 on success). Use a RETURNING clause via
# execute/rows if you need a generated key (backend-specific).
proc ::tclutils::tutdbc::insert {conn table data} {
    variable NULLVAL
    if {[dict size $data] == 0} {
        return -code error -errorcode {TCLUTILS TUTDBC EMPTY} \
            "insert needs at least one column"
    }
    set cols {}
    set phs  {}
    set binds [dict create]
    set i 0
    dict for {k v} $data {
        lappend cols [quoteId $k]
        lappend phs  ":c$i"
        if {$v ne $NULLVAL} { dict set binds "c$i" $v }  ;# omit -> SQL NULL
        incr i
    }
    set sql "INSERT INTO [quoteId $table] ([join $cols ,]) VALUES ([join $phs ,])"
    return [execute $conn $sql $binds]
}

# transaction conn script -- run script in a transaction; commit on success,
# roll back on error (re-raising it). The script runs in the caller's scope.
proc ::tclutils::tutdbc::transaction {conn script} {
    $conn begintransaction
    set code [catch {uplevel 1 $script} result options]
    if {$code == 0} {
        $conn commit
        return $result
    }
    catch {$conn rollback}
    return -options $options $result
}

package provide tclutils::tutdbc 0.1
