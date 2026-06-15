# tclutils::tudeploy -- runtime discovery + loading of Tcl module packages from
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
        set os [expr {$::tcl_platform(os) eq "Darwin" ? "macos" : "linux"}]
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

# Add the roots to tcl::tm::path; return the list actually added.
proc ::tclutils::tudeploy::addModulePaths {args} {
    set rs [roots {*}$args]
    foreach r $rs { catch {::tcl::tm::path add $r} }
    return $rs
}

# Ensure roots are on tm path (unless -tmadd 0), then `package require` each.
# Returns 1 iff all succeed; with -fail 1 throws {TCLUTILS TUDEPLOY REQUIRE}.
proc ::tclutils::tudeploy::require {packages args} {
    set opt(fail)  0
    set opt(tmadd) 1
    set passthru {}
    set n [llength $args]
    for {set i 0} {$i < $n} {incr i 2} {
        set k [lindex $args $i]
        if {[string index $k 0] ne "-"} { _err OPTION "expected an option, got \"$k\"" }
        if {$i+1 >= $n} { _err OPTION "option \"$k\" requires a value" }
        set v [lindex $args [expr {$i+1}]]
        switch -- $k {
            -fail   { set opt(fail)  $v }
            -tmadd  { set opt(tmadd) $v }
            default { lappend passthru $k $v }
        }
    }
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
    if {![catch {package present $pkg}]} { return 1 }
    set opt(fail) 0
    set dirsGiven {}
    set passthru {}
    set n [llength $args]
    for {set i 0} {$i < $n} {incr i 2} {
        set k [lindex $args $i]
        if {[string index $k 0] ne "-"} { _err OPTION "expected an option, got \"$k\"" }
        if {$i+1 >= $n} { _err OPTION "option \"$k\" requires a value" }
        set v [lindex $args [expr {$i+1}]]
        switch -- $k {
            -fail { set opt(fail) $v }
            -dirs { set dirsGiven $v }
            default { lappend passthru $k $v }
        }
    }
    if {[llength $dirsGiven]} {
        set dirs [_existingUnique $dirsGiven]
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

package provide tclutils::tudeploy 0.1
