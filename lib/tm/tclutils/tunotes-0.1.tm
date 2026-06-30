# tclutils::tunotes -- hierarchical note store
# Description: hierarchical note store
# Category: Data · structures & formats
#
# A small, dependency-light engine for a tree of notes. Notes are plain dicts
# with the fields: id parent_id title content created modified tags. The whole
# collection ("store") is itself a dict mapping id -> note, so it is just a
# value that can be copied, compared and serialized.
#
# Mutating commands take the NAME of a store variable (by upvar); query
# commands take the store value. Persistence uses the pure-Tcl JSON engine
# tclutils::tujson (no external packages).

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tujson 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tunotes {
    namespace export create update delete move get exists roots children \
        descendants parent path search byTag tags ids count toJson fromJson \
        load save \
        setTitle setContent addTag removeTag hasTag ancestors siblings depth \
        subtree
}

proc ::tclutils::tunotes::_now {} {
    return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
}

proc ::tclutils::tunotes::_genId {store} {
    set id [clock microseconds]
    while {[dict exists $store $id]} { incr id }
    return $id
}

proc ::tclutils::tunotes::_require {store id} {
    if {![dict exists $store $id]} {
        return -code error -errorcode {TCLUTILS TUNOTES NOTFOUND} \
            "Note not found: $id"
    }
}

# Create a note. Returns its new id. Mutates the named store.
proc ::tclutils::tunotes::create {storeVar title content {tags {}} {parentId ""}} {
    upvar 1 $storeVar store
    if {![info exists store]} { set store [dict create] }
    if {$parentId ne "" && ![dict exists $store $parentId]} {
        return -code error -errorcode {TCLUTILS TUNOTES NOTFOUND} \
            "Parent note not found: $parentId"
    }
    set id [_genId $store]
    set ts [_now]
    dict set store $id [dict create \
        id $id parent_id $parentId title $title content $content \
        created $ts modified $ts tags $tags]
    return $id
}

# Update a note. Pass parentId "KEEP" (default) to leave the parent unchanged.
proc ::tclutils::tunotes::update {storeVar id title content {tags {}} {parentId KEEP}} {
    upvar 1 $storeVar store
    _require $store $id
    set note [dict get $store $id]
    dict set note title $title
    dict set note content $content
    dict set note tags $tags
    dict set note modified [_now]
    if {$parentId ne "KEEP"} { dict set note parent_id $parentId }
    dict set store $id $note
    return $id
}

# Delete a note. cascade=1 deletes the whole subtree; cascade=0 reparents the
# direct children to the root.
proc ::tclutils::tunotes::delete {storeVar id {cascade 1}} {
    upvar 1 $storeVar store
    _require $store $id
    foreach childId [children $store $id] {
        if {$cascade} {
            delete store $childId 1
        } else {
            set c [dict get $store $childId]
            dict set c parent_id ""
            dict set store $childId $c
        }
    }
    dict unset store $id
    return
}

# Move a note under a new parent ("" = root). Refuses to create a cycle.
proc ::tclutils::tunotes::move {storeVar id newParentId} {
    upvar 1 $storeVar store
    _require $store $id
    if {$newParentId ne "" && ![dict exists $store $newParentId]} {
        return -code error -errorcode {TCLUTILS TUNOTES NOTFOUND} \
            "Parent note not found: $newParentId"
    }
    if {$newParentId eq $id || $newParentId in [descendants $store $id]} {
        return -code error -errorcode {TCLUTILS TUNOTES CYCLE} \
            "Cannot move a note under itself or a descendant"
    }
    set note [dict get $store $id]
    dict set note parent_id $newParentId
    dict set note modified [_now]
    dict set store $id $note
    return
}

proc ::tclutils::tunotes::get {store id} {
    _require $store $id
    return [dict get $store $id]
}

proc ::tclutils::tunotes::exists {store id} {
    return [dict exists $store $id]
}

# Ids of all notes without a parent, in insertion order.
proc ::tclutils::tunotes::roots {store} {
    set out {}
    dict for {id note} $store {
        if {[dict get $note parent_id] eq ""} { lappend out $id }
    }
    return $out
}

# Ids of the direct children of a note, in insertion order.
proc ::tclutils::tunotes::children {store parentId} {
    set out {}
    dict for {id note} $store {
        if {[dict get $note parent_id] eq $parentId} { lappend out $id }
    }
    return $out
}

# Ids of all descendants (depth-first).
proc ::tclutils::tunotes::descendants {store id} {
    set out {}
    foreach c [children $store $id] {
        lappend out $c
        lappend out {*}[descendants $store $c]
    }
    return $out
}

proc ::tclutils::tunotes::parent {store id} {
    _require $store $id
    return [dict get [dict get $store $id] parent_id]
}

# Ids from the root down to the note (inclusive).
proc ::tclutils::tunotes::path {store id} {
    set acc {}
    set cur $id
    while {$cur ne "" && [dict exists $store $cur]} {
        set acc [linsert $acc 0 $cur]
        set cur [dict get [dict get $store $cur] parent_id]
    }
    return $acc
}

# Ids whose title or content contains the query (case-insensitive).
proc ::tclutils::tunotes::search {store query} {
    set out {}
    dict for {id note} $store {
        if {[string match -nocase *$query* [dict get $note title]] ||
            [string match -nocase *$query* [dict get $note content]]} {
            lappend out $id
        }
    }
    return $out
}

proc ::tclutils::tunotes::byTag {store tag} {
    set out {}
    dict for {id note} $store {
        if {$tag in [dict get $note tags]} { lappend out $id }
    }
    return $out
}

proc ::tclutils::tunotes::tags {store} {
    set seen [dict create]
    dict for {id note} $store {
        foreach t [dict get $note tags] { dict set seen $t 1 }
    }
    return [lsort [dict keys $seen]]
}

proc ::tclutils::tunotes::ids {store} {
    return [dict keys $store]
}

proc ::tclutils::tunotes::count {store} {
    return [dict size $store]
}

# Serialize the store to a pretty-printed JSON object.
proc ::tclutils::tunotes::toJson {store} {
    set Q ::tclutils::tujson::quote
    set notes {}
    dict for {id note} $store {
        set fields {}
        foreach key {id parent_id title content created modified} {
            lappend fields "[$Q $key]:[$Q [dict get $note $key]]"
        }
        set tg {}
        foreach t [dict get $note tags] { lappend tg [$Q $t] }
        lappend fields "[$Q tags]:\[[join $tg ,]\]"
        lappend notes "[$Q $id]:\{[join $fields ,]\}"
    }
    return [::tclutils::tujson::pretty "\{[join $notes ,]\}"]
}

# Parse a JSON object back into a store, filling missing fields with defaults.
proc ::tclutils::tunotes::fromJson {json} {
    if {[string trim $json] eq ""} { return [dict create] }
    set raw [::tclutils::tujson::parse $json]
    set store [dict create]
    dict for {id note} $raw {
        set n [dict create id $id parent_id "" title "" content "" \
            created "" modified "" tags {}]
        foreach key {id parent_id title content created modified tags} {
            if {[dict exists $note $key]} { dict set n $key [dict get $note $key] }
        }
        dict set store $id $n
    }
    return $store
}

# Load a store from a JSON file. A missing/empty file yields an empty store.
proc ::tclutils::tunotes::load {path} {
    if {![file exists $path]} { return [dict create] }
    return [fromJson [::tclutils::common::readFile $path]]
}

# Save a store to a JSON file.
proc ::tclutils::tunotes::save {store path} {
    ::tclutils::common::writeFile $path [toJson $store]
    return
}

# --- field mutators ---

# Set only the title (touches modified).
proc ::tclutils::tunotes::setTitle {storeVar id title} {
    upvar 1 $storeVar store
    _require $store $id
    set note [dict get $store $id]
    dict set note title $title
    dict set note modified [_now]
    dict set store $id $note
    return $id
}

# Set only the content (touches modified).
proc ::tclutils::tunotes::setContent {storeVar id content} {
    upvar 1 $storeVar store
    _require $store $id
    set note [dict get $store $id]
    dict set note content $content
    dict set note modified [_now]
    dict set store $id $note
    return $id
}

# --- tag helpers ---

# Add a tag if not already present.
proc ::tclutils::tunotes::addTag {storeVar id tag} {
    upvar 1 $storeVar store
    _require $store $id
    set note [dict get $store $id]
    set tags [dict get $note tags]
    if {$tag ni $tags} {
        lappend tags $tag
        dict set note tags $tags
        dict set note modified [_now]
        dict set store $id $note
    }
    return $id
}

# Remove a tag if present.
proc ::tclutils::tunotes::removeTag {storeVar id tag} {
    upvar 1 $storeVar store
    _require $store $id
    set note [dict get $store $id]
    set tags [dict get $note tags]
    set idx [lsearch -exact $tags $tag]
    if {$idx >= 0} {
        set tags [lreplace $tags $idx $idx]
        dict set note tags $tags
        dict set note modified [_now]
        dict set store $id $note
    }
    return $id
}

proc ::tclutils::tunotes::hasTag {store id tag} {
    _require $store $id
    return [expr {$tag in [dict get [dict get $store $id] tags]}]
}

# --- hierarchy helpers ---

# Ids from the root down to (but excluding) the note.
proc ::tclutils::tunotes::ancestors {store id} {
    return [lrange [path $store $id] 0 end-1]
}

# Ids of notes sharing the same parent, excluding the note itself.
proc ::tclutils::tunotes::siblings {store id} {
    _require $store $id
    set pid [dict get [dict get $store $id] parent_id]
    set out {}
    foreach c [children $store $pid] {
        if {$c ne $id} { lappend out $c }
    }
    return $out
}

# Number of ancestors (root = 0).
proc ::tclutils::tunotes::depth {store id} {
    return [llength [ancestors $store $id]]
}

# A standalone store-dict containing the note (re-rooted: parent_id "") and all
# of its descendants. Useful for exporting a branch.
proc ::tclutils::tunotes::subtree {store id} {
    _require $store $id
    set sub [dict create]
    set root [dict get $store $id]
    dict set root parent_id ""
    dict set sub $id $root
    foreach d [descendants $store $id] {
        dict set sub $d [dict get $store $d]
    }
    return $sub
}

package provide tclutils::tunotes 0.1
