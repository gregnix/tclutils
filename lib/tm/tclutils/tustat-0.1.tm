# tclutils::tustat -- stat-like file metadata helpers
# Description: stat-like file metadata helpers
# Category: Archive · filesystem
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tustat {
    namespace export file files render
    variable version 0.1
}

proc ::tclutils::tustat::file {path} {
    ::file stat $path st
    set result [dict create]
    foreach key [lsort [array names st]] {
        dict set result $key $st($key)
    }
    dict set result path $path
    dict set result normalized [::file normalize $path]
    dict set result type [::file type $path]
    return $result
}

proc ::tclutils::tustat::files {paths} {
    set out {}
    foreach path $paths {
        lappend out [file $path]
    }
    return $out
}

proc ::tclutils::tustat::render {statDict args} {
    set defaults [dict create -timeformat {%Y-%m-%d %H:%M:%S}]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set fmt [dict get $opts -timeformat]
    set lines {}
    foreach key {path type size mtime mode ino dev uid gid} {
        if {[dict exists $statDict $key]} {
            set value [dict get $statDict $key]
            if {$key in {mtime atime ctime}} {
                set value [clock format $value -format $fmt]
            }
            lappend lines [::format {%-10s %s} $key $value]
        }
    }
    return [join $lines \n]
}

package provide tclutils::tustat 0.1
