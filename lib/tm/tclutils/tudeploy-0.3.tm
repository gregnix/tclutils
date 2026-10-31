# tclutils::tudeploy -- runtime discovery + loading of Tcl module packages from
# Description: runtime discovery and loading of Tcl module packages from app-relative deployment roots
# Category: System · runtime
# application-relative deployment roots, plus locating bundled resource dirs.
#
# Pure Tcl, no external dependencies. Library-neutral: takes package lists and
# root conventions as arguments; knows nothing about any specific application.
#
# Tcl 8.6-
package require Tcl 8.6-

namespace eval ::tclutils::tudeploy {
    namespace export baseDirs platformTag roots addModulePaths require resourceDirs sourceModule
    namespace ensemble create

    # Default module-root convention, relative to each base dir (and parent).
    # A root is a directory that CONTAINS package-named subdirs, e.g.
    # <root>/<pkg>/<mod>-<ver>.tm, so `package require <pkg>::<mod>` resolves.
    variable defaultRoots {vendor {libs common} libs {lib tm}}
}

proc ::tclutils::tudeploy::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUDEPLOY $reason] $msg
}

# Parse "-key value ..." into the upvar'd opt() array; only `allowed` keys ok.
proc ::tclutils::tudeploy::_parseOpts {arrName allowed argList} {
    upvar 1 $arrName opt
    if {[llength $argList] % 2} {
        _err OPTION "option \"[lindex $argList end]\" requires a value"
    }
    foreach {k v} $argList {
        if {[string index $k 0] ne "-"} { _err OPTION "expected an option, got \"$k\"" }
        set name [string range $k 1 end]
        if {$name ni $allowed} { _err OPTION "unknown option \"$k\"" }
        set opt($name) $v
    }
}

# Split "-key value ..." for require/sourceModule: own options (names in
# $own, without "-") go into the upvar'd opt() array, the root options of
# `roots` are collected and returned; anything else raises OPTION. Own
# options listed in $bools must be booleans (VALUE otherwise).
proc ::tclutils::tudeploy::_splitOpts {arrName own bools argList} {
    upvar 1 $arrName opt
    set passthru {}
    set n [llength $argList]
    for {set i 0} {$i < $n} {incr i 2} {
        set k [lindex $argList $i]
        if {[string index $k 0] ne "-"} { _err OPTION "expected an option, got \"$k\"" }
        if {$i+1 >= $n} { _err OPTION "option \"$k\" requires a value" }
        set v [lindex $argList [expr {$i+1}]]
        set name [string range $k 1 end]
        if {$name in $own} {
            if {$name in $bools} {
                if {![string is boolean -strict $v]} {
                    _err VALUE "option \"$k\" requires a boolean value"
                }
                set v [expr {$v ? 1 : 0}]
            }
            set opt($name) $v
        } elseif {$name in {base env roots parents}} {
            lappend passthru $k $v
        } else {
            _err OPTION "unknown option \"$k\""
        }
    }
    return $passthru
}

proc ::tclutils::tudeploy::_existingUnique {dirs} {
    set out {}
    foreach d $dirs {
        if {$d eq ""} continue
        if {[file isdirectory $d] && $d ni $out} { lappend out $d }
    }
    return $out
}

# Application base directories: the dir of the main script (argv0) and the dir
# of the running executable. Normalised, de-duplicated, existing only. Apps with
# an unusual layout can override everywhere via `-base {dir ...}`.
proc ::tclutils::tudeploy::baseDirs {} {
    set out {}
    foreach src [list $::argv0 [info nameofexecutable]] {
        if {$src eq ""} continue
        set d [file dirname [file normalize $src]]
        if {[file isdirectory $d] && $d ni $out} { lappend out $d }
    }
    return $out
}

# Platform tag "<os><bits>", e.g. linux64 / windows64 / macos64.
proc ::tclutils::tudeploy::platformTag {} {
    set os $::tcl_platform(platform)
    if {$os eq "unix"} {
        if {$::tcl_platform(os) eq "Darwin"} {
            set os macos
        } else {
            set os linux
        }
    }
    set bits [expr {$::tcl_platform(pointerSize) == 4 ? 32 : 64}]
    return $os$bits
}

# Ordered list of EXISTING module roots. -env values are prepended verbatim.
proc ::tclutils::tudeploy::roots {args} {
    variable defaultRoots
    set opt(base)    [baseDirs]
    set opt(env)     {}
    set opt(roots)   $defaultRoots
    set opt(parents) 1
    _parseOpts opt {base env roots parents} $args
    set dirs {}
    foreach v $opt(env) {
        if {[info exists ::env($v)] && $::env($v) ne ""} { lappend dirs $::env($v) }
    }
    set bases $opt(base)
    if {$opt(parents)} {
        foreach b $opt(base) { lappend bases [file dirname $b] }
    }
    foreach b $bases {
        foreach rel $opt(roots) { lappend dirs [file join $b {*}$rel] }
    }
    return [_existingUnique $dirs]
}

# Add the roots to tcl::tm::path; return the roots that are on the module
# path afterwards (newly added or already there). A root that tcl::tm::path
# refuses (it lies inside, or contains, a registered root) is left out.
proc ::tclutils::tudeploy::addModulePaths {args} {
    set rs [roots {*}$args]
    set out {}
    foreach r $rs {
        if {[catch {::tcl::tm::path add $r}]} continue
        if {$r in [::tcl::tm::path list]} { lappend out $r }
    }
    return $out
}

# Ensure roots are on tm path (unless -tmadd 0), then `package require` each.
# Returns 1 iff all succeed; with -fail 1 throws {TCLUTILS TUDEPLOY REQUIRE}.
proc ::tclutils::tudeploy::require {packages args} {
    set opt(fail)  0
    set opt(tmadd) 1
    set passthru [_splitOpts opt {fail tmadd} {fail tmadd} $args]
    if {$opt(tmadd)} { addModulePaths {*}$passthru }
    set missing {}
    foreach p $packages {
        if {[catch {package require $p}]} { lappend missing $p }
    }
    if {[llength $missing]} {
        if {$opt(fail)} { _err REQUIRE "package(s) not found: $missing" }
        return 0
    }
    return 1
}

# Ordered list of EXISTING candidate dirs for a bundled resource <name>
# (e.g. a decoder), to feed to `tuexe::find -dirs` or the caller's own glob.
proc ::tclutils::tudeploy::resourceDirs {name args} {
    if {$name eq ""} { _err USAGE "resourceDirs: a resource name is required" }
    set opt(base)    [baseDirs]
    set opt(env)     {}
    set opt(parents) 1
    set opt(tag)     [platformTag]
    _parseOpts opt {base env parents tag} $args
    # name and tag are folders below vendor/: an absolute name or ".." would
    # lead out of it (up to 0.2 "/tmp" or "../../x" became a candidate)
    foreach {what v} [list name $name tag $opt(tag)] {
        if {[file pathtype $v] ne "relative" || ".." in [file split $v]} {
            _err USAGE "resourceDirs: $what must stay below vendor/: $v"
        }
    }
    set dirs {}
    foreach v $opt(env) {
        if {[info exists ::env($v)] && $::env($v) ne ""} { lappend dirs $::env($v) }
    }
    set bases $opt(base)
    if {$opt(parents)} {
        foreach b $opt(base) { lappend bases [file dirname $b] }
    }
    foreach b $bases {
        lappend dirs \
            [file join $b vendor $name $opt(tag)] \
            [file join $b vendor $name] \
            [file join $b vendor $opt(tag)] \
            [file join $b vendor] \
            [file join $b bin] \
            $b
    }
    return [_existingUnique $dirs]
}

# Load a package by sourcing its module file directly, bypassing tcl::tm
# discovery. Use for packages whose vendored .tm sits at a path that does not
# match its package name (e.g. a bare package "qpdf" shipped as
# vendor/qpdf/lib/qpdf-0.2.tm with sibling shared libraries), where a dedicated
# tm root would be an ancestor/descendant of an already-registered root and
# tcl::tm::path refuses it. Searches the resolved dirs for "<tail>-<ver>.tm"
# (tail = last :: component of pkg), sources the highest version, and verifies
# the package became present. Returns 1/0, or throws {TCLUTILS TUDEPLOY REQUIRE}
# with -fail 1.
proc ::tclutils::tudeploy::sourceModule {pkg args} {
    set opt(fail) 0
    set opt(dirs) {}
    set passthru [_splitOpts opt {fail dirs} {fail} $args]
    if {![catch {package present $pkg}]} { return 1 }
    if {[llength $opt(dirs)]} {
        set dirs [_existingUnique $opt(dirs)]
    } else {
        set dirs [roots {*}$passthru]
    }
    set tail [namespace tail $pkg]
    set cands {}
    foreach d $dirs {
        foreach f [glob -nocomplain -directory $d -- $tail-*.tm] {
            set ver [string range [file tail $f] [expr {[string length $tail]+1}] end-3]
            if {[catch {package vcompare $ver $ver}]} continue
            lappend cands [list $ver $f]
        }
    }
    set cands [lsort -decreasing -command \
        {apply {{a b} {package vcompare [lindex $a 0] [lindex $b 0]}}} $cands]
    foreach c $cands {
        if {[catch {uplevel #0 [list source [lindex $c 1]]}]} continue
        if {![catch {package present $pkg}]} { return 1 }
    }
    if {$opt(fail)} { _err REQUIRE "could not source module for package: $pkg" }
    return 0
}

package provide tclutils::tudeploy 0.3
