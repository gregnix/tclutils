# tclutils::tufind -- portable file finder in pure Tcl
# Description: portable file finder in pure Tcl
# Category: Archive · filesystem
# Tcl 8.6+

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tufind {
    namespace export files directories all walk
    variable version 0.1.3
}

proc ::tclutils::tufind::NormalizePatterns {patterns} {
    if {[llength $patterns] == 0} { return [list *] }
    if {[llength $patterns] == 1} {
        set p [lindex $patterns 0]
        if {[llength $p] > 1} { return $p }
    }
    return $patterns
}

proc ::tclutils::tufind::MatchAny {path patterns fullpath} {
    set tail [file tail $path]
    foreach pattern $patterns {
        if {[string match $pattern $tail]} { return 1 }
        if {$fullpath && [string match $pattern $path]} { return 1 }
    }
    return 0
}

proc ::tclutils::tufind::ParseOptions {args} {
    set opts [dict create \
        -recursive 1 \
        -mindepth 0 \
        -maxdepth -1 \
        -type file \
        -hidden 0 \
        -fullpath 1 \
        -tails 0 \
        -followlinks 0 \
        -size {} \
        -mtime {}]

    set patterns {}
    set root .
    set haveRoot 0

    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        if {[string match -* $a]} {
            if {![dict exists $opts $a]} { error "unknown option $a" }
            incr i
            if {$i >= [llength $args]} { error "missing value for option $a" }
            dict set opts $a [lindex $args $i]
        } else {
            if {!$haveRoot} {
                set root $a
                set haveRoot 1
            } else {
                lappend patterns $a
            }
        }
        incr i
    }

    set patterns [NormalizePatterns $patterns]
    return [list $root $patterns $opts]
}

proc ::tclutils::tufind::ShouldSkipHidden {path hidden} {
    if {$hidden} { return 0 }
    set tail [file tail $path]
    if {$tail eq "." || $tail eq ".."} { return 1 }
    return [string match .* $tail]
}

proc ::tclutils::tufind::ParseSizeSpec {spec} {
    if {$spec eq ""} { return [list any 0] }
    set op exact
    set value $spec
    if {[regexp {^([+-])(.*)$} $spec -> sign rest]} {
        set op [expr {$sign eq "+" ? "gt" : "lt"}]
        set value $rest
    }
    if {![regexp {^([0-9]+)([kKmMgG]?)$} $value -> number unit]} {
        error "bad -size value '$spec': expected N, +N, -N, optionally with k, m, or g"
    }
    set mult 1
    switch -- [string tolower $unit] {
        k { set mult 1024 }
        m { set mult [expr {1024*1024}] }
        g { set mult [expr {1024*1024*1024}] }
    }
    return [list $op [expr {$number * $mult}]]
}

proc ::tclutils::tufind::MatchSize {path spec} {
    if {$spec eq ""} { return 1 }
    if {![file isfile $path]} { return 0 }
    lassign [ParseSizeSpec $spec] op limit
    set size [file size $path]
    switch -- $op {
        exact { return [expr {$size == $limit}] }
        gt    { return [expr {$size >  $limit}] }
        lt    { return [expr {$size <  $limit}] }
    }
}

proc ::tclutils::tufind::ParseMtimeSpec {spec} {
    if {$spec eq ""} { return [list any 0] }
    set op exact
    set value $spec
    if {[regexp {^([+-])(.*)$} $spec -> sign rest]} {
        set op [expr {$sign eq "+" ? "older" : "newer"}]
        set value $rest
    }
    if {![string is integer -strict $value]} {
        error "bad -mtime value '$spec': expected days as integer, optionally +N or -N"
    }
    return [list $op $value]
}

proc ::tclutils::tufind::MatchMtime {path spec now} {
    if {$spec eq ""} { return 1 }
    lassign [ParseMtimeSpec $spec] op days
    set ageDays [expr {int(($now - [file mtime $path]) / 86400)}]
    switch -- $op {
        exact { return [expr {$ageDays == $days}] }
        older { return [expr {$ageDays >  $days}] }
        newer { return [expr {$ageDays <  $days}] }
    }
}

proc ::tclutils::tufind::AcceptedByType {path type} {
    set isDir [file isdirectory $path]
    set isFile [file isfile $path]
    switch -- $type {
        file { return $isFile }
        directory - dir { return $isDir }
        any - all { return 1 }
        default { error "bad -type value '$type': expected file, directory, dir, any, or all" }
    }
}

proc ::tclutils::tufind::WalkInternal {root patterns opts depth resultVar callback now} {
    upvar 1 $resultVar result

    if {![file exists $root]} { return }

    set type [dict get $opts -type]
    set mindepth [dict get $opts -mindepth]
    set maxdepth [dict get $opts -maxdepth]
    set recursive [dict get $opts -recursive]
    set hidden [dict get $opts -hidden]
    set fullpath [dict get $opts -fullpath]
    set tails [dict get $opts -tails]
    set followlinks [dict get $opts -followlinks]
    set sizeSpec [dict get $opts -size]
    set mtimeSpec [dict get $opts -mtime]

    if {[ShouldSkipHidden $root $hidden] && $depth > 0} { return }

    set isDir [file isdirectory $root]
    set isLink [expr {[file type $root] eq "link"}]

    if {$depth >= $mindepth \
            && [AcceptedByType $root $type] \
            && [MatchAny $root $patterns $fullpath] \
            && [MatchSize $root $sizeSpec] \
            && [MatchMtime $root $mtimeSpec $now]} {
        set value [expr {$tails ? [file tail $root] : $root}]
        if {$callback ne ""} {
            uplevel #0 [list {*}$callback $value]
        } else {
            lappend result $value
        }
    }

    if {!$isDir || !$recursive} { return }
    if {$maxdepth >= 0 && $depth >= $maxdepth} { return }
    if {$isLink && !$followlinks} { return }

    set children {}
    foreach pattern [list * .*] {
        foreach child [glob -nocomplain -directory $root $pattern] {
            set tail [file tail $child]
            if {$tail eq "." || $tail eq ".."} { continue }
            # On some platforms/glob implementations, dot files may be returned
            # by both "*" and ".*".  Normalize and de-duplicate here so that a
            # file such as ".hidden" is processed only once.
            dict set children [file normalize $child] $child
        }
    }

    foreach child [dict values $children] {
        WalkInternal $child $patterns $opts [expr {$depth + 1}] result $callback $now
    }
}

proc ::tclutils::tufind::Run {args} {
    lassign [ParseOptions {*}$args] root patterns opts
    set result {}
    WalkInternal [file normalize $root] $patterns $opts 0 result "" [clock seconds]
    return [lsort -dictionary $result]
}

proc ::tclutils::tufind::all {args} {
    lassign [ParseOptions {*}$args] root patterns opts
    dict set opts -type all
    set result {}
    WalkInternal [file normalize $root] $patterns $opts 0 result "" [clock seconds]
    return [lsort -dictionary $result]
}

proc ::tclutils::tufind::files {args} {
    lassign [ParseOptions {*}$args] root patterns opts
    dict set opts -type file
    set result {}
    WalkInternal [file normalize $root] $patterns $opts 0 result "" [clock seconds]
    return [lsort -dictionary $result]
}

proc ::tclutils::tufind::directories {args} {
    lassign [ParseOptions {*}$args] root patterns opts
    dict set opts -type directory
    set result {}
    WalkInternal [file normalize $root] $patterns $opts 0 result "" [clock seconds]
    return [lsort -dictionary $result]
}

proc ::tclutils::tufind::walk {root patterns callback args} {
    set patterns [NormalizePatterns [list $patterns]]
    set opts [dict create \
        -recursive 1 \
        -mindepth 0 \
        -maxdepth -1 \
        -type file \
        -hidden 0 \
        -fullpath 1 \
        -tails 0 \
        -followlinks 0 \
        -size {} \
        -mtime {}]
    foreach {k v} $args {
        if {![dict exists $opts $k]} { error "unknown option $k" }
        dict set opts $k $v
    }
    set result {}
    WalkInternal [file normalize $root] $patterns $opts 0 result $callback [clock seconds]
    return
}

package provide tclutils::tufind 0.1
