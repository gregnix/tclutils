# tclutils::tupkgfinder -- inspect how Tcl resolves packages: known versions,
# Description: inspect how Tcl resolves packages: versions, ifneeded scripts, locations, active vs shadowed
# Category: System · runtime
# their `ifneeded` scripts and source locations, which version is active vs.
# shadowed, the relevant search paths, and an optional filesystem search by
# pattern. candidates/shadows (0.2) list every copy on the search paths,
# also a second copy with the same version that the package database never
# shows. Pure Tcl, library-neutral, no GUI.
#
# Tcl 8.6-
package require Tcl 8.6-

namespace eval ::tclutils::tupkgfinder {
    namespace export paths versions pkgInfo which report findFileSystem \
        candidates shadows
}

proc ::tclutils::tupkgfinder::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUPKGFINDER $reason] $msg
}

# auto_path and tcl::tm::path as a dict {auto_path {pos path ...} tm_path {...}}.
proc ::tclutils::tupkgfinder::paths {} {
    set result {}
    set pos 0
    foreach p $::auto_path {
        dict set result auto_path $pos $p
        incr pos
    }
    if {[llength [::info commands ::tcl::tm::path]]} {
        set pos 0
        foreach p [::tcl::tm::path list] {
            dict set result tm_path $pos $p
            incr pos
        }
    }
    return $result
}

# Known versions of a package (as reported by the package database).
proc ::tclutils::tupkgfinder::versions {packageName} {
    return [package versions $packageName]
}

# Full record for a package: versions, ifneeded scripts, and extracted
# source locations per version.
proc ::tclutils::tupkgfinder::pkgInfo {packageName} {
    set result [dict create package $packageName]
    set versions [package versions $packageName]
    dict set result versions $versions
    foreach version $versions {
        set script [package ifneeded $packageName $version]
        dict set result ifneeded $version $script
        dict set result locations $version [_extractPaths $script]
    }
    return $result
}

# Best-effort extraction of the final source path from an ifneeded script.
# Handles simple patterns such as:
#   source /path/pkgIndex.tcl
#   ...;source -encoding utf-8 /path/file.tm
proc ::tclutils::tupkgfinder::_ifneededSourcePath {script} {
    set p ""
    if {[regexp {source\s+(?:-encoding\s+\S+\s+)?([^\s;]+)} $script -> raw]} {
        set cleaned [string trim $raw "\"'{}"]
        if {![catch {file normalize $cleaned} n]} {
            set p $n
        } else {
            set p $cleaned
        }
    }
    return $p
}

# Resolution view for a package: found versions/paths, the active version and
# its path (per Tcl's selection rules), and any shadowed paths.
# Note: this calls `package require` to determine the active version, which
# loads the package as a side effect.
proc ::tclutils::tupkgfinder::which {packageName} {
    set result [dict create package $packageName]
    set found {}
    set shadowed {}
    set active ""
    set activeVersion ""

    set versions [package versions $packageName]
    dict set result versions $versions

    foreach v $versions {
        set script [package ifneeded $packageName $v]
        set src [_ifneededSourcePath $script]
        if {$src eq ""} {
            set locs [_extractPaths $script]
            if {$locs ne {}} { set src [lindex $locs 0] }
        }
        if {$src eq ""} continue
        lappend found [dict create version $v path $src script $script]
    }
    set found [lsort -unique -index end $found]
    dict set result found $found

    if {![catch {set activeVersion [package require $packageName]}]} {
        foreach item $found {
            if {[dict get $item version] eq $activeVersion} {
                set active [dict get $item path]
                break
            }
        }
    }
    dict set result activeVersion $activeVersion
    dict set result activePath $active

    foreach item $found {
        if {$active ne "" && [dict get $item path] ne $active} {
            lappend shadowed [dict get $item path]
        }
    }
    dict set result shadowed [lsort -unique $shadowed]
    return $result
}

# Extract existing file paths referenced by an ifneeded script.
proc ::tclutils::tupkgfinder::_extractPaths {script} {
    set found {}
    # 1) token-wise path detection
    foreach part $script {
        if {[catch {file exists $part} exists]} { continue }
        if {$exists} {
            if {![catch {file normalize $part} normalized]} {
                lappend found $normalized
            }
        } elseif {[regexp {[/\\]} $part]} {
            set cleaned [string trim $part "\"'{}"]
            if {[catch {file exists $cleaned} cexists]} { continue }
            if {$cexists && ![catch {file normalize $cleaned} normalized]} {
                lappend found $normalized
            }
        }
    }
    # 2) scan the script text for typical file paths
    set pathPatterns {
        {(?i)(/[^ \t\r\n\}\{\"\']+\.(?:tcl|tm|so|dll|dylib))}
        {(?i)([A-Za-z]:/[^\s\}\{\"\']+\.(?:tcl|tm|so|dll|dylib))}
        {(?i)(\./[^\s\}\{\"\']+\.(?:tcl|tm|so|dll|dylib))}
        {(?i)(\.\./[^\s\}\{\"\']+\.(?:tcl|tm|so|dll|dylib))}
    }
    foreach re $pathPatterns {
        foreach match [regexp -all -inline $re $script] {
            set cleaned [string trim $match "\"'{}"]
            if {[catch {file exists $cleaned} exists]} { continue }
            if {$exists && ![catch {file normalize $cleaned} normalized]} {
                lappend found $normalized
            }
        }
    }
    return [lsort -unique $found]
}

# Search the filesystem for files matching a glob pattern.
#   findFileSystem pattern
#   findFileSystem pattern rootsList
#   findFileSystem pattern ?-roots list? ?-maxdepth N? ?-followlinks 0|1?
#                          ?-maxfiles N? ?-excludeDirs list?
# Without -roots a platform default set is scanned (can be slow).
proc ::tclutils::tupkgfinder::findFileSystem {pattern args} {
    set opts [dict create \
        roots {} \
        maxdepth -1 \
        followlinks 0 \
        maxfiles -1 \
        excludeDirs {.git .svn node_modules __pycache__ .cache .tox .venv} \
    ]
    if {[llength $args] == 1 && ![string match -* [lindex $args 0]]} {
        dict set opts roots [lindex $args 0]
    } elseif {[llength $args] > 0} {
        if {[llength $args] % 2 != 0} {
            _err OPTION "option/value pairs expected"
        }
        foreach {k v} $args {
            switch -- $k {
                -roots       { dict set opts roots $v }
                -maxdepth    { dict set opts maxdepth $v }
                -followlinks { dict set opts followlinks $v }
                -maxfiles    { dict set opts maxfiles $v }
                -excludeDirs { dict set opts excludeDirs $v }
                default      { _err OPTION "unknown option \"$k\"" }
            }
        }
    }
    set roots [dict get $opts roots]
    if {$roots eq {}} { set roots [_defaultRoots] }
    set result {}
    set visited {}
    set stats [dict create scanned 0 stop 0]
    foreach root $roots {
        if {[dict get $stats stop]} break
        if {[catch {file exists $root} exists] || !$exists} continue
        _walk $root $pattern result visited stats 0 $opts
    }
    return [lsort -unique $result]
}

proc ::tclutils::tupkgfinder::_defaultRoots {} {
    set roots {}
    lappend roots [pwd]
    lappend roots [file normalize ~]
    switch -- $::tcl_platform(platform) {
        unix {
            foreach p {/usr/lib /usr/local/lib /opt /usr/share /usr/local/share} {
                if {[file exists $p]} { lappend roots $p }
            }
        }
        windows {
            foreach p {C:/Tcl C:/Tcl90 {C:/Program Files} {C:/Program Files (x86)}} {
                if {[file exists $p]} { lappend roots $p }
            }
        }
        default {
            foreach p {/Library/Tcl /System/Library/Tcl /usr/local/lib /opt/local/lib} {
                if {[file exists $p]} { lappend roots $p }
            }
        }
    }
    return [lsort -unique $roots]
}

proc ::tclutils::tupkgfinder::_walk {dir pattern resultVar visitedVar statsVar depth opts} {
    upvar 1 $resultVar result $visitedVar visited $statsVar stats
    if {[dict get $stats stop]} return
    set maxdepth [dict get $opts maxdepth]
    if {$maxdepth >= 0 && $depth > $maxdepth} return
    if {[catch {file type $dir} t]} return
    if {$t eq "link" && ![dict get $opts followlinks]} return
    if {[catch {file normalize $dir} normDir]} return
    if {[dict exists $visited $normDir]} return
    dict set visited $normDir 1
    if {[catch {glob -nocomplain -directory $dir *} entries]} return
    foreach entry $entries {
        if {[dict get $stats stop]} break
        if {[catch {file tail $entry} tail]} continue
        dict set stats scanned [expr {[dict get $stats scanned] + 1}]
        set maxfiles [dict get $opts maxfiles]
        if {$maxfiles >= 0 && [dict get $stats scanned] >= $maxfiles} {
            dict set stats stop 1
            break
        }
        if {[string match -nocase $pattern $tail]} {
            if {![catch {file normalize $entry} normalized]} {
                lappend result $normalized
            }
        }
        if {[catch {file type $entry} etype]} continue
        if {$etype eq "directory"} {
            if {$tail in [dict get $opts excludeDirs]} continue
            _walk $entry $pattern result visited stats [expr {$depth + 1}] $opts
        } elseif {$etype eq "link" && [dict get $opts followlinks]} {
            if {$tail in [dict get $opts excludeDirs]} continue
            _walk $entry $pattern result visited stats [expr {$depth + 1}] $opts
        }
    }
}

# Human-readable diagnostic report for a single package.
proc ::tclutils::tupkgfinder::report {packageName} {
    set out {}
    append out "Package: $packageName\n"
    append out "Tcl: [info patchlevel]\n"
    append out "Platform: $::tcl_platform(platform)\n\n"
    append out "Versions:\n"
    set versions [package versions $packageName]
    if {$versions eq {}} {
        append out "  not known by Tcl package system\n"
    } else {
        foreach version $versions { append out "  $version\n" }
    }
    append out "\nIfneeded:\n"
    foreach version $versions {
        append out "  $version:\n"
        append out "    [package ifneeded $packageName $version]\n"
    }
    append out "\nauto_path:\n"
    set i 0
    foreach p $::auto_path { append out "  $i: $p\n"; incr i }
    append out "\ntm path:\n"
    if {[llength [::info commands ::tcl::tm::path]]} {
        set i 0
        foreach p [::tcl::tm::path list] { append out "  $i: $p\n"; incr i }
    } else {
        append out "  not available\n"
    }
    return $out
}

# ---------------------------------------------------------------------------
# Every copy of a package on the search paths (0.2).
#
# The package database keeps ONE ifneeded script per version, so a second
# copy with the same version (an installed pdf4tcl next to the working tree,
# say) never shows up in [package versions]. These procs look at the files.
# ---------------------------------------------------------------------------

# candidates ?-pattern glob? ?-tmpaths list? ?-autopath list?
# A list of dicts {package version kind path}: kind "tm" (path = the .tm
# file, from the module paths) or "pkgIndex" (path = the pkgIndex.tcl in an
# auto_path directory or one level below, as Tcl's own search does). Only
# literal "package ifneeded NAME VERSION" lines of a pkgIndex.tcl are seen.
proc ::tclutils::tupkgfinder::candidates {args} {
    set pattern *
    set tmpaths {}
    if {[llength [::info commands ::tcl::tm::path]]} { set tmpaths [::tcl::tm::path list] }
    set autopath $::auto_path
    if {[llength $args] % 2} { _err OPTION "option/value pairs expected" }
    foreach {k v} $args {
        switch -- $k {
            -pattern  { set pattern $v }
            -tmpaths  { set tmpaths $v }
            -autopath { set autopath $v }
            default   { _err OPTION "unknown option \"$k\" (-pattern, -tmpaths, -autopath)" }
        }
    }
    set out {}
    set seen {}
    foreach root $tmpaths {
        if {![file isdirectory $root]} continue
        foreach f [_tmFiles $root] {
            set nf [file normalize $f]
            if {[dict exists $seen $nf]} continue
            dict set seen $nf 1
            set rel [file split [string range $nf [string length [file normalize $root]] end]]
            set rel [lrange $rel 1 end]          ;# drop the leading separator
            if {![regexp {^([_[:alpha:]][:_[:alnum:]]*)-([[:digit:]].*)\.tm$} \
                    [lindex $rel end] -> name ver]} continue
            if {[catch {package vcompare $ver 0}]} continue
            set pkg [join [concat [lrange $rel 0 end-1] [list $name]] ::]
            if {![string match $pattern $pkg]} continue
            lappend out [dict create package $pkg version $ver kind tm path $nf]
        }
    }
    foreach dir $autopath {
        if {![file isdirectory $dir]} continue
        set idxs [glob -nocomplain -types f -directory $dir pkgIndex.tcl]
        lappend idxs {*}[glob -nocomplain -types f -directory $dir */pkgIndex.tcl]
        foreach idx $idxs {
            set ni [file normalize $idx]
            if {[dict exists $seen $ni]} continue
            dict set seen $ni 1
            if {[catch {open $ni r} fh]} continue
            set text [read $fh]
            close $fh
            foreach {- name ver} [regexp -all -inline \
                    {package\s+ifneeded\s+([^\s\[\]$\"\{\}]+)\s+([0-9][^\s\[\]$\"\{\}]*)} $text] {
                if {[catch {package vcompare $ver 0}]} continue
                if {![string match $pattern $name]} continue
                lappend out [dict create package $name version $ver kind pkgIndex path $ni]
            }
        }
    }
    return $out
}

proc ::tclutils::tupkgfinder::_tmFiles {dir} {
    set out [glob -nocomplain -types f -directory $dir *.tm]
    foreach d [glob -nocomplain -types d -directory $dir *] {
        lappend out {*}[_tmFiles $d]
    }
    return $out
}

# shadows ?-pattern glob? ?-all 0|1? ?-tmpaths list? ?-autopath list?
# One dict per package that has more than one copy (all packages with
# -all 1): {package P active VERSION activePath PATH duplicate 0|1
# candidates {{version V kind K path P status S} ...}}. Status is "active"
# (the copy [package require] takes), "same version" (a second copy of the
# active version that is NOT used -- the dangerous case), or "other version".
# duplicate is 1 when any version has more than one copy.
# Side effect: for a package whose copies are not all registered yet, an
# unsatisfiable [package require] runs Tcl's package unknown handlers, so
# the pkgIndex.tcl files and that module directory are read (nothing is
# loaded).
proc ::tclutils::tupkgfinder::shadows {args} {
    set all 0
    set cargs {}
    if {[llength $args] % 2} { _err OPTION "option/value pairs expected" }
    foreach {k v} $args {
        switch -- $k {
            -all { set all $v }
            -pattern - -tmpaths - -autopath { lappend cargs $k $v }
            default { _err OPTION "unknown option \"$k\" (-pattern, -all, -tmpaths, -autopath)" }
        }
    }
    set by {}
    set seen {}
    foreach c [candidates {*}$cargs] {
        # a pkgIndex.tcl may name one version twice (if/else per Tcl version)
        set key [list [dict get $c package] [dict get $c version] [dict get $c path]]
        if {[dict exists $seen $key]} continue
        dict set seen $key 1
        dict lappend by [dict get $c package] $c
    }
    set out {}
    foreach pkg [lsort -dictionary [dict keys $by]] {
        set cands [dict get $by $pkg]
        if {!$all && [llength $cands] < 2} continue
        # Let Tcl register what it would find: an unsatisfiable request runs
        # the package unknown handlers (module search for this name, every
        # pkgIndex.tcl) and loads nothing.
        foreach c $cands {
            if {[dict get $c version] ni [package versions $pkg]} {
                catch {package require $pkg 99999-}
                break
            }
        }
        set active ""
        if {[catch {package present $pkg} active]} {
            set active ""
            set vs [package versions $pkg]
            if {[llength $vs]} {
                set active [lindex [lsort -command {package vcompare} $vs] end]
            }
        }
        set activePath ""
        set activeScript ""
        if {$active ne ""} {
            set activeScript [package ifneeded $pkg $active]
            set activePath [_ifneededSourcePath $activeScript]
            if {$activePath eq ""} {
                set activePath [lindex [_extractPaths $activeScript] 0]
            }
        }
        set count {}
        foreach c $cands { dict incr count [dict get $c version] }
        set dup 0
        dict for {v n} $count { if {$n > 1} { set dup 1 } }
        set rows {}
        foreach c $cands {
            set v [dict get $c version]
            set p [dict get $c path]
            if {$v ne $active} {
                set st "other version"
            } elseif {[_sameSource [dict get $c kind] $p $activePath $activeScript]} {
                set st active
            } else {
                set st "same version"
            }
            lappend rows [dict create version $v kind [dict get $c kind] path $p status $st]
        }
        set rows [lsort -command [list apply {{a b} {
            set r [package vcompare [dict get $b version] [dict get $a version]]
            if {$r == 0} { set r [string compare [dict get $a path] [dict get $b path]] }
            return $r
        }}] $rows]
        lappend out [dict create package $pkg active $active activePath $activePath \
            duplicate $dup candidates $rows]
    }
    return $out
}

# Is the registered source ACTIVEPATH this candidate? A .tm file must match
# exactly; for a pkgIndex.tcl the source lies in its directory or below.
# Without a file in the script (tclPkgSetup, load with a computed name) the
# directory of the pkgIndex.tcl must appear in the script text.
proc ::tclutils::tupkgfinder::_sameSource {kind path activePath script} {
    if {$kind eq "tm"} {
        if {$activePath eq ""} { return 0 }
        return [expr {[file normalize $path] eq [file normalize $activePath]}]
    }
    set dir [file normalize [file dirname $path]]
    if {$activePath ne ""} {
        return [string match "$dir/*" [file normalize $activePath]]
    }
    return [expr {[string first $dir $script] >= 0}]
}

package provide tclutils::tupkgfinder 0.2
