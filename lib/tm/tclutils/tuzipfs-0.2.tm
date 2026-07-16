# tclutils::tuzipfs -- small Tcl 9 zipfs convenience wrapper
# Description: small Tcl 9 zipfs convenience wrapper, plus zipfs-image primitives
# Category: Archive · filesystem
# Tcl 8.6+: package can load everywhere; commands requiring zipfs throw a clear error.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuzipfs {
    namespace export available requireAvailable root mounts mount unmount \
        listFiles find exists readFile withMounted \
        rcopy copyStdlib mkimg buildImage
    variable version 0.2
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

# ---------------------------------------------------------------------------
# Image primitives (Tcl 9 zipkit assembly)
#
# These help turn an application directory into a self-contained zipkit with
# `zipfs mkimg`. Two facts drive the design and are easy to get wrong:
#
#   1. `zipfs mkimg` REPLACES the ZIP archive attached to the basekit. A
#      BAWT/magicsplat basekit ships its own standard library inside that
#      archive (mounted at `//zipfs:/app/tcl_library`). An image built with only
#      the application therefore loses the stdlib and will not even start.
#      `copyStdlib` puts the stdlib back into the VFS tree before mkimg.
#
#   2. Copying files OUT of a mounted zipfs with `[file copy]` is unreliable.
#      `rcopy` reads/writes bytes explicitly, so it works from zipfs and from
#      ordinary directories alike.
# ---------------------------------------------------------------------------

# Recursive byte-exact copy. Safe from a mounted zipfs source.
proc ::tclutils::tuzipfs::rcopy {src dst} {
    if {[file isdirectory $src]} {
        file mkdir $dst
        foreach e [glob -nocomplain -directory $src *] {
            rcopy $e [file join $dst [file tail $e]]
        }
    } else {
        file mkdir [file dirname $dst]
        set in [open $src rb]
        try { set data [read $in] } finally { close $in }
        set out [open $dst wb]
        try { puts -nonewline $out $data } finally { close $out }
    }
    return $dst
}

# Copy the Tcl (and optionally Tk) standard-library trees into destDir, so an
# image built onto a basekit keeps a working stdlib.
#
#   -tk 0|1        also copy tk_library (needed for GUI/wish images)
#   -from running  use the CURRENT interpreter's [info library] / $::tk_library
#                  (run this under the target basekit so versions match)
#   -from DIR      DIR must contain tcl_library/ (and tk_library/ when -tk 1);
#                  use this for cross-platform builds -- mount the foreign
#                  basekit read-only and point -from at its mountpoint.
proc ::tclutils::tuzipfs::copyStdlib {destDir args} {
    set opts [::tclutils::common::parseOptions {
        -tk 0
        -from running
    } {*}$args]
    set wantTk [::tclutils::common::ensureBoolean [dict get $opts -tk] -tk]
    set from [dict get $opts -from]
    file mkdir $destDir

    if {$from eq "running"} {
        rcopy [info library] [file join $destDir tcl_library]
        if {$wantTk} {
            if {![info exists ::tk_library] || $::tk_library eq ""} {
                return -code error -errorcode {TCLUTILS TUZIPFS NOTK} \
                    "-tk 1 requested but \$::tk_library is not set; run under a\
                     wish/Tk basekit, or use -from DIR"
            }
            rcopy $::tk_library [file join $destDir tk_library]
        }
    } else {
        set tclLib [file join $from tcl_library]
        if {![file isdirectory $tclLib]} {
            return -code error -errorcode {TCLUTILS TUZIPFS NOSTDLIB} \
                "no tcl_library under \"$from\""
        }
        rcopy $tclLib [file join $destDir tcl_library]
        if {$wantTk} {
            set tkLib [file join $from tk_library]
            if {![file isdirectory $tkLib]} {
                return -code error -errorcode {TCLUTILS TUZIPFS NOTK} \
                    "no tk_library under \"$from\""
            }
            rcopy $tkLib [file join $destDir tk_library]
        }
    }
    return $destDir
}

# Thin, checked wrapper over `zipfs mkimg`. Files in indir land at the image's
# archive root because -strip defaults to indir.
#
#   -strip DIR      path prefix to strip (default: indir)
#   -basekit FILE   template interpreter; default = the running executable,
#                   which must itself be a static zipkit
#   -password PW    optional archive password
proc ::tclutils::tuzipfs::mkimg {outfile indir args} {
    requireAvailable
    set opts [::tclutils::common::parseOptions {
        -strip ""
        -basekit ""
        -password ""
    } {*}$args]
    if {![file isdirectory $indir]} {
        return -code error -errorcode {TCLUTILS TUZIPFS NODIR} \
            "not a directory: \"$indir\""
    }
    set strip [dict get $opts -strip]
    if {$strip eq ""} { set strip $indir }
    set basekit [dict get $opts -basekit]
    set pw [dict get $opts -password]
    if {$basekit eq ""} {
        zipfs mkimg $outfile $indir $strip $pw
    } else {
        zipfs mkimg $outfile $indir $strip $pw $basekit
    }
    return $outfile
}

# One-call convenience: (optionally) drop the stdlib into an already-assembled
# VFS tree, then build the image.
#
#   -out FILE       output executable (required)
#   -vfs DIR        assembled VFS directory (required)
#   -basekit FILE   template basekit (default: running executable)
#   -stdlib none|cli|gui   copy no stdlib / tcl_library / tcl_library+tk_library
#   -stdlibfrom running|DIR   passed to copyStdlib -from
proc ::tclutils::tuzipfs::buildImage {args} {
    set opts [::tclutils::common::parseOptions {
        -out ""
        -vfs ""
        -basekit ""
        -stdlib none
        -stdlibfrom running
    } {*}$args]
    set out [dict get $opts -out]
    set vfs [dict get $opts -vfs]
    if {$out eq "" || $vfs eq ""} {
        return -code error -errorcode {TCLUTILS TUZIPFS OPTION} \
            "-out and -vfs are required"
    }
    set stdlib [dict get $opts -stdlib]
    switch -- $stdlib {
        none {}
        cli  { copyStdlib $vfs -tk 0 -from [dict get $opts -stdlibfrom] }
        gui  { copyStdlib $vfs -tk 1 -from [dict get $opts -stdlibfrom] }
        default {
            return -code error -errorcode {TCLUTILS TUZIPFS OPTION} \
                "-stdlib must be none, cli or gui"
        }
    }
    return [mkimg $out $vfs -strip $vfs -basekit [dict get $opts -basekit]]
}

package provide tclutils::tuzipfs 0.2
