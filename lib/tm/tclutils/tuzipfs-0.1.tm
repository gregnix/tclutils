# tclutils::tuzipfs -- small Tcl 9 zipfs convenience wrapper
# Description: small Tcl 9 zipfs convenience wrapper
# Category: Archive · filesystem
# Tcl 8.6+: package can load everywhere; commands requiring zipfs throw a clear error.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuzipfs {
    namespace export available requireAvailable root mounts mount unmount listFiles find exists readFile withMounted
    variable version 0.1
}

proc ::tclutils::tuzipfs::available {} {
    return [expr {[llength [info commands ::zipfs]] > 0}]
}

proc ::tclutils::tuzipfs::requireAvailable {} {
    if {![available]} {
        return -code error -errorcode {TCLUTILS TUZIPFS UNAVAILABLE} \
            "zipfs is not available in this Tcl interpreter; Tcl 9 is required"
    }
    return 1
}

proc ::tclutils::tuzipfs::root {} {
    requireAvailable
    return [zipfs root]
}

proc ::tclutils::tuzipfs::mounts {} {
    requireAvailable
    return [zipfs mount]
}

proc ::tclutils::tuzipfs::mount {archive {mountName ""}} {
    requireAvailable
    if {$mountName eq ""} {
        set mountName [format {tclutils_%s_%s} [pid] [clock clicks]]
    }
    return [zipfs mount $archive $mountName]
}

proc ::tclutils::tuzipfs::unmount {mountpoint} {
    requireAvailable
    zipfs unmount $mountpoint
    return $mountpoint
}

proc ::tclutils::tuzipfs::listFiles {mountpoint args} {
    requireAvailable
    set opts [::tclutils::common::parseOptions {
        -glob *
        -recursive 1
    } {*}$args]
    set pattern [dict get $opts -glob]
    set recursive [::tclutils::common::ensureBoolean [dict get $opts -recursive] -recursive]

    if {$recursive} {
        set files [zipfs find $mountpoint]
    } else {
        set files [glob -nocomplain -directory $mountpoint $pattern]
        return [lsort $files]
    }

    set out {}
    foreach path $files {
        if {$pattern eq "*" || [string match $pattern [file tail $path]] || [string match $pattern $path]} {
            lappend out $path
        }
    }
    return [lsort $out]
}

proc ::tclutils::tuzipfs::find {mountpoint args} {
    return [::tclutils::tuzipfs::listFiles $mountpoint {*}$args]
}

proc ::tclutils::tuzipfs::exists {path} {
    requireAvailable
    return [zipfs exists $path]
}

proc ::tclutils::tuzipfs::readFile {path} {
    requireAvailable
    return [::tclutils::common::readBinaryFile $path]
}

proc ::tclutils::tuzipfs::withMounted {archive varName body args} {
    set opts [::tclutils::common::parseOptions {
        -mount ""
    } {*}$args]
    set mountpoint [mount $archive [dict get $opts -mount]]
    upvar 1 $varName mp
    set mp $mountpoint
    try {
        return [uplevel 1 $body]
    } finally {
        unmount $mountpoint
    }
}

package provide tclutils::tuzipfs 0.1
