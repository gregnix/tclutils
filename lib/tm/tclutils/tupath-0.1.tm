# tclutils::tupath -- path utilities (normalize, lexical clean, commonpath, ...)
# Description: path utilities (normalize, lexical clean, commonpath, ...)
# Category: Archive · filesystem
# Tcl 8.6+
#
# Thin, predictable helpers around Tcl's `file` command plus two things the
# core does not offer directly: a purely lexical `clean` (no filesystem access,
# works on non-existent paths) and `commonPath` (longest shared directory).

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tupath {
    namespace export normalize clean isAbsolute components join \
        relative commonPath readlink
    variable version 0.1
}

# Filesystem-resolving normalization (absolute, resolves . .. and symlinks).
proc ::tclutils::tupath::normalize {path} {
    return [file normalize $path]
}

# Purely lexical cleanup: collapse "." and ".." and redundant separators
# WITHOUT touching the filesystem. Safe for paths that do not exist.
proc ::tclutils::tupath::clean {path} {
    if {$path eq ""} { return "." }
    set abs [isAbsolute $path]
    set out {}
    foreach p [file split $path] {
        if {$p eq "/" || $p eq ""} { continue }
        if {$p eq "."} { continue }
        if {$p eq ".."} {
            if {[llength $out] > 0 && [lindex $out end] ne ".."} {
                set out [lrange $out 0 end-1]
            } elseif {!$abs} {
                lappend out ".."
            }
            continue
        }
        lappend out $p
    }
    if {$abs} {
        return [file join / {*}$out]
    }
    if {[llength $out] == 0} { return "." }
    return [file join {*}$out]
}

proc ::tclutils::tupath::isAbsolute {path} {
    return [expr {[file pathtype $path] eq "absolute"}]
}

proc ::tclutils::tupath::components {path} {
    return [file split $path]
}

proc ::tclutils::tupath::join {args} {
    return [file join {*}$args]
}

# Path of `target` expressed relative to `base`. Purely lexical; both paths
# must be the same type (both absolute or both relative).
proc ::tclutils::tupath::relative {base target} {
    if {[file pathtype $base] ne [file pathtype $target]} {
        return -code error -errorcode {TCLUTILS TUPATH RELATIVE} \
            "base and target must both be absolute or both relative"
    }
    set b [file split [clean $base]]
    set t [file split [clean $target]]
    set min [expr {min([llength $b], [llength $t])}]
    set i 0
    while {$i < $min && [lindex $b $i] eq [lindex $t $i]} { incr i }
    set parts {}
    for {set j $i} {$j < [llength $b]} {incr j} { lappend parts ".." }
    foreach c [lrange $t $i end] { lappend parts $c }
    if {[llength $parts] == 0} { return "." }
    return [file join {*}$parts]
}

# Longest common directory prefix of a list of paths. Returns "" if the paths
# share no leading component (e.g. one absolute and one relative).
proc ::tclutils::tupath::commonPath {paths} {
    if {[llength $paths] == 0} {
        return -code error -errorcode {TCLUTILS TUPATH ARGS} \
            "commonPath needs at least one path"
    }
    set split {}
    foreach p $paths { lappend split [file split $p] }
    set first [lindex $split 0]
    set common {}
    for {set i 0} {$i < [llength $first]} {incr i} {
        set comp [lindex $first $i]
        set ok 1
        foreach s $split {
            if {$i >= [llength $s] || [lindex $s $i] ne $comp} { set ok 0; break }
        }
        if {!$ok} { break }
        lappend common $comp
    }
    if {[llength $common] == 0} { return "" }
    return [file join {*}$common]
}

# Symlink target; errors with {TCLUTILS TUPATH NOTLINK} if not a symlink.
proc ::tclutils::tupath::readlink {path} {
    if {[catch {file readlink $path} res]} {
        return -code error -errorcode {TCLUTILS TUPATH NOTLINK} \
            "not a symbolic link: $path"
    }
    return $res
}

package provide tclutils::tupath 0.1
