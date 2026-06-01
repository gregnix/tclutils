# tclutils::tuuniq -- uniq-like helpers
package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuuniq { namespace export uniqList text file count countText countFile adjacentCount }

proc ::tclutils::tuuniq::_parseOptions {args} {
    set opts [dict create -nocase 0]
    set i 0
    while {$i < [llength $args]} {
        set opt [lindex $args $i]
        if {![dict exists $opts $opt]} {
            return -code error "unknown option \"$opt\""
        }
        incr i
        if {$i >= [llength $args]} {
            return -code error "missing value for option \"$opt\""
        }
        set val [lindex $args $i]
        if {![string is boolean -strict $val]} {
            return -code error "option \"$opt\" requires a boolean value"
        }
        dict set opts $opt [expr {$val ? 1 : 0}]
        incr i
    }
    return $opts
}

proc ::tclutils::tuuniq::_key {value nocase} {
    if {$nocase} { return [string tolower $value] }
    return $value
}

proc ::tclutils::tuuniq::uniqList {items args} {
    set opts [_parseOptions {*}$args]
    set nocase [dict get $opts -nocase]
    set out {}
    set havePrev 0
    set prevKey ""
    foreach item $items {
        set key [_key $item $nocase]
        if {!$havePrev || $key ne $prevKey} {
            lappend out $item
            set prevKey $key
            set havePrev 1
        }
    }
    return $out
}

proc ::tclutils::tuuniq::adjacentCount {items args} {
    set opts [_parseOptions {*}$args]
    set nocase [dict get $opts -nocase]
    set out {}
    set havePrev 0
    set prevKey ""
    set prevValue ""
    set n 0
    foreach item $items {
        set key [_key $item $nocase]
        if {!$havePrev} {
            set prevKey $key; set prevValue $item; set n 1; set havePrev 1
        } elseif {$key eq $prevKey} {
            incr n
        } else {
            lappend out [::list $n $prevValue]
            set prevKey $key; set prevValue $item; set n 1
        }
    }
    if {$havePrev} { lappend out [::list $n $prevValue] }
    return $out
}

proc ::tclutils::tuuniq::count {items args} {
    # Counts all occurrences, not only adjacent ones.  Result is a dict.
    set opts [_parseOptions {*}$args]
    set nocase [dict get $opts -nocase]
    set counts [dict create]
    foreach item $items {
        set key [_key $item $nocase]
        dict incr counts $key
    }
    return $counts
}

proc ::tclutils::tuuniq::text {text args} {
    set lines [split $text \n]
    if {[llength $lines] > 0 && [lindex $lines end] eq ""} {
        set lines [lrange $lines 0 end-1]
    }
    return [join [::tclutils::tuuniq::uniqList $lines {*}$args] \n]
}

proc ::tclutils::tuuniq::file {path args} {
    set data [::tclutils::common::readFile $path]
    return [text $data {*}$args]
}

proc ::tclutils::tuuniq::countText {text args} {
    set lines [split $text \n]
    if {[llength $lines] > 0 && [lindex $lines end] eq ""} {
        set lines [lrange $lines 0 end-1]
    }
    return [count $lines {*}$args]
}

proc ::tclutils::tuuniq::countFile {path args} {
    set data [::tclutils::common::readFile $path]
    return [countText $data {*}$args]
}

package provide tclutils::tuuniq 0.1
