# tclutils::tuappinfo -- collect application / system information into a plain
# Description: collect Tcl/Tk, executable, platform and environment info into a plain text report
# Category: System · runtime
# text report: Tcl/Tk versions and libraries, executable, platform, selected
# environment, the variables that steer the package search, search paths
# (missing folders marked), loaded packages with their origin, loaded binary
# libraries (info loaded), the build of the Tcl library (tcl::pkgconfig,
# tclConfig.sh), and optionally a list of explicitly tracked module files. Supports anonymisation of user/host/path data. Pure Tcl,
# library-neutral, no GUI (rendering is left to the caller).
#
# Anonymisation rule for paths (-anonymize 1): a path equal to or below the
# home directory ($HOME, else $USERPROFILE) becomes <HOME>/rest, every other
# path becomes <path>/<last component>. TEMP/TMP become <TEMP>, PATH
# <anonymized>, tracked module files <tm-HASH>.tm.
#
# Error codes: {TCLUTILS TUAPPINFO OPTION|VALUE}.
#
# Tcl 8.6-, tclutils::common 0.3 (writeLog)
package require Tcl 8.6-
package require tclutils::common 0.3

namespace eval ::tclutils::tuappinfo {
    namespace export trackTm buildReport writeLog
    variable loadedTm {}
}

# ------------------------------------------------------------
# Public API
# ------------------------------------------------------------

# Record a module file path so it appears under "Loaded TM Modules".
proc ::tclutils::tuappinfo::trackTm {file} {
    variable loadedTm
    lappend loadedTm $file
}

# Build the full report as a single string.
#   buildReport ?-title str? ?-anonymize 0|1?
proc ::tclutils::tuappinfo::buildReport {args} {
    array set opt {
        -title     "Application Information"
        -anonymize 0
    }
    set n [llength $args]
    for {set i 0} {$i < $n} {incr i 2} {
        set k [lindex $args $i]
        if {![info exists opt($k)]} {
            return -code error -errorcode {TCLUTILS TUAPPINFO OPTION} \
                "unknown option \"$k\": must be -title or -anonymize"
        }
        if {$i + 1 >= $n} {
            return -code error -errorcode {TCLUTILS TUAPPINFO OPTION} \
                "option \"$k\" requires a value"
        }
        set opt($k) [lindex $args [expr {$i + 1}]]
    }
    if {![string is boolean -strict $opt(-anonymize)]} {
        return -code error -errorcode {TCLUTILS TUAPPINFO VALUE} \
            "-anonymize requires a boolean value"
    }
    set opt(-anonymize) [expr {$opt(-anonymize) ? 1 : 0}]
    set an $opt(-anonymize)
    set report {}
    lappend report {*}[_collectCoreInfo    $opt(-title) $an]
    lappend report {*}[_collectBuild       $an]
    lappend report {*}[_collectEnvironment $an]
    lappend report {*}[_collectSearchVars  $an]
    lappend report {*}[_collectAutoPath    $an]
    lappend report {*}[_collectPackages    $an]
    lappend report {*}[_collectLibraries   $an]
    lappend report {*}[_collectTmPaths     $an]
    lappend report {*}[_collectLoadedTm    $an]
    return [join $report "\n"]
}

# Write the report to a file (same options as buildReport).
proc ::tclutils::tuappinfo::writeLog {file args} {
    set txt [buildReport {*}$args]
    # temporary file, then rename: a failed write keeps an old log (0.3)
    ::tclutils::common::replaceFile $file "$txt\n" -encoding utf-8 -translation auto
    return $file
}

# ------------------------------------------------------------
# Internals
# ------------------------------------------------------------

# Simple stable hash for anonymisation (not cryptographic).
proc ::tclutils::tuappinfo::_hash {s} {
    set h 0
    foreach c [split $s ""] {
        scan $c %c v
        set h [expr {($h * 33 + $v) & 0x7fffffff}]
    }
    return [format %08x $h]
}

# The home directory used for masking ("" when unknown), with "/" separators.
proc ::tclutils::tuappinfo::_home {} {
    foreach var {HOME USERPROFILE} {
        if {[info exists ::env($var)] && $::env($var) ne ""} {
            return [string trimright [string map {\\ /} $::env($var)] /]
        }
    }
    return ""
}

# Mask one path: below $home -> <HOME>/rest, otherwise <path>/<last part>.
proc ::tclutils::tuappinfo::_maskPath {p home} {
    if {$p eq ""} { return "" }
    set q [string map {\\ /} $p]
    set nocase [expr {$::tcl_platform(platform) eq "windows"}]
    if {$home ne ""} {
        set len [string length $home]
        set head [string range $q 0 [expr {$len - 1}]]
        if {$nocase} {
            set same [string equal -nocase $head $home]
        } else {
            set same [string equal $head $home]
        }
        set next [string index $q $len]
        if {$same && ($next eq "" || $next eq "/")} {
            return "<HOME>[string range $q $len end]"
        }
    }
    set tail [lindex [split [string trimright $q /] /] end]
    return "<path>/$tail"
}

# A path as shown in the report: masked on request (0.3).
proc ::tclutils::tuappinfo::_showPath {p anonymize} {
    if {$anonymize} {
        return [_maskPath $p [_home]]
    }
    return $p
}

# One line for a search folder: "  path", with " (missing)" when the folder
# does not exist (0.3).
proc ::tclutils::tuappinfo::_dirLine {p anonymize} {
    set line "  [_showPath $p $anonymize]"
    if {![file isdirectory $p]} {
        append line " (missing)"
    }
    return $line
}

# Separator of path lists in environment variables.
proc ::tclutils::tuappinfo::_pathSep {} {
    if {$::tcl_platform(platform) eq "windows"} {
        return ";"
    }
    return ":"
}

proc ::tclutils::tuappinfo::_collectCoreInfo {title anonymize} {
    set info {}
    lappend info "==== $title ===="
    lappend info "Timestamp: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
    lappend info "PID: [pid]"
    lappend info ""
    lappend info "--- Tcl / Tk ---"
    lappend info "Tcl version: [info patchlevel]"
    lappend info "Tcl library: [_showPath [info library] $anonymize]"
    if {[info exists ::tk_version]} {
        # the patch level, as for Tcl (0.3; was tk_version, "9.0")
        if {[info exists ::tk_patchLevel]} {
            set _tk $::tk_patchLevel
        } else {
            set _tk $::tk_version
        }
        lappend info "Tk version: $_tk"
        if {[info exists ::tk_library]} {
            lappend info "Tk library: [_showPath $::tk_library $anonymize]"
        }
        if {[llength [info commands ::tk]]
                && ![catch {::tk windowingsystem} ws]} {
            lappend info "Windowing system: $ws"
        }
    }
    lappend info "Executable: [_showPath [info nameofexecutable] $anonymize]"
    lappend info "Platform: $::tcl_platform(os) $::tcl_platform(osVersion)"
    lappend info "Machine: $::tcl_platform(machine)"
    # info hostname on every platform; COMPUTERNAME as fallback (0.3)
    set host ""
    catch {set host [info hostname]}
    if {$host eq "" && [info exists ::env(COMPUTERNAME)]} {
        set host $::env(COMPUTERNAME)
    }
    if {$host ne ""} {
        if {$anonymize} {
            lappend info "Host: <host-[_hash $host]>"
        } else {
            lappend info "Host: $host"
        }
    }
    return $info
}

# One value of tcl::pkgconfig, "" when the key is missing (older Tcl).
proc ::tclutils::tuappinfo::_pkgconfig {key} {
    if {[catch {::tcl::pkgconfig get $key} v]} { return "" }
    return $v
}

# Same directory? Both normalized; Windows compares without case.
proc ::tclutils::tuappinfo::_sameDir {a b} {
    set a [file normalize $a]
    set b [file normalize $b]
    if {$::tcl_platform(platform) eq "windows"} {
        return [string equal -nocase $a $b]
    }
    return [string equal $a $b]
}

# Does the executable belong to the installation the Tcl library was built
# for? "" if yes or unknown, else a note (0.3). bindir is the library's
# bindir,install: a library from another installation reports that one's;
# a moved installation reports a folder that no longer exists.
proc ::tclutils::tuappinfo::_buildNote {exe bindir} {
    if {$exe eq "" || $bindir eq ""} { return "" }
    if {[_sameDir [file dirname $exe] $bindir]} { return "" }
    if {![file isdirectory $bindir]} {
        return "bindir,install does not exist: the installation was moved or copied after building"
    }
    return "the executable is not in bindir,install: the Tcl library comes from another installation"
}

# The Tcl library file this process has mapped, from /proc/<pid>/maps
# (Linux only, "" elsewhere or when Tcl is linked statically) (0.3).
proc ::tclutils::tuappinfo::_loadedTclLib {} {
    set maps /proc/[pid]/maps
    if {![file readable $maps] || [catch {open $maps r} fh]} { return "" }
    set data [read $fh]
    close $fh
    foreach line [split $data \n] {
        set f [lindex $line end]
        if {[regexp {/libtcl[0-9][0-9.]*\.so[0-9.]*$} $f]} { return $f }
    }
    return ""
}

# Read a tclConfig.sh: {version patchlevel prefix}, e.g. {9.0 9.0.4 /usr}.
# A forwarder that only sources another file gives {"" "" ""}.
proc ::tclutils::tuappinfo::_readTclConfig {file} {
    set ver "" ; set pl "" ; set prefix ""
    if {[catch {open $file r} fh]} { return [list "" "" ""] }
    set data [read $fh]
    close $fh
    foreach line [split $data \n] {
        if {![regexp {^TCL_(VERSION|PATCH_LEVEL|PREFIX)=['"]?([^'"]*)['"]?\s*$} \
                $line -> key val]} {
            continue
        }
        switch -- $key {
            VERSION     { if {$ver eq ""}    { set ver $val } }
            PATCH_LEVEL { if {$pl eq ""}     { set pl $val } }
            PREFIX      { if {$prefix eq ""} { set prefix $val } }
        }
    }
    set full $ver
    if {$ver ne "" && [string match .* $pl]} { append full $pl }
    return [list $ver $full $prefix]
}

# The tclConfig.sh of the running installation: next to the library
# (libdir,install, Debian in tclX.Y below it), else lib/ beside the
# executable's bin/. "" if none with a version line is found (0.3).
proc ::tclutils::tuappinfo::_tclConfig {} {
    set v [info tclversion]
    set cands {}
    foreach libdir [list [_pkgconfig libdir,install] [_pkgconfig libdir,runtime]] {
        if {$libdir eq ""} continue
        lappend cands [file join $libdir tcl$v tclConfig.sh] \
                      [file join $libdir tclConfig.sh]
    }
    set lib [_loadedTclLib]
    if {$lib ne ""} {
        lappend cands [file join [file dirname $lib] tcl$v tclConfig.sh] \
                      [file join [file dirname $lib] tclConfig.sh]
    }
    set exe [info nameofexecutable]
    if {$exe ne ""} {
        lappend cands [file join [file dirname [file dirname $exe]] lib tclConfig.sh]
    }
    foreach c $cands {
        if {[file readable $c] && [lindex [_readTclConfig $c] 0] ne ""} {
            return $c
        }
    }
    return ""
}

# The build of the loaded Tcl library (0.3): tcl::pkgconfig belongs to the
# library, not to the executable, so a mismatch shows a mixed installation.
proc ::tclutils::tuappinfo::_collectBuild {anonymize} {
    set info {}
    lappend info ""
    lappend info "--- Build ---"
    set flags {}
    foreach k {threaded 64bit debug optimized} {
        set val [_pkgconfig $k]
        if {$val ne ""} { lappend flags "$k=$val" }
    }
    if {[llength $flags]} { lappend info "Flags: [join $flags { }]" }
    foreach k {bindir,install libdir,runtime scriptdir,runtime} {
        set val [_pkgconfig $k]
        if {$val ne ""} { lappend info "$k: [_showPath $val $anonymize]" }
    }
    set dll [_pkgconfig dllfile,runtime]
    if {$dll ne ""} { lappend info "dllfile,runtime: $dll" }
    set lib [_loadedTclLib]
    if {$lib ne ""} { lappend info "Library file: [_showPath $lib $anonymize]" }
    set note [_buildNote [info nameofexecutable] [_pkgconfig bindir,install]]
    if {$note ne ""} { lappend info "Note: $note" }
    set cfg [_tclConfig]
    if {$cfg eq ""} {
        lappend info "tclConfig.sh: (none found; the -dev package or build tree is missing)"
    } else {
        lassign [_readTclConfig $cfg] - full prefix
        lappend info "tclConfig.sh: [_showPath $cfg $anonymize]"
        if {$full ne [info patchlevel]} {
            lappend info "  TCL_PATCH_LEVEL: $full (differs from [info patchlevel])"
        }
        if {$prefix ne ""} {
            set line "  TCL_PREFIX: [_showPath $prefix $anonymize]"
            if {![file isdirectory $prefix]} { append line " (missing)" }
            lappend info $line
        }
    }
    return $info
}

proc ::tclutils::tuappinfo::_collectEnvironment {anonymize} {
    set info {}
    lappend info ""
    lappend info "--- Environment ---"
    foreach var {USER USERNAME HOME TEMP TMP} {
        if {![info exists ::env($var)]} continue
        if {$anonymize} {
            switch $var {
                USER - USERNAME { lappend info "$var: <user-[_hash $::env($var)]>" }
                HOME            { lappend info "$var: <HOME>" }
                TEMP - TMP      { lappend info "$var: <TEMP>" }
            }
        } else {
            lappend info "$var: $::env($var)"
        }
    }
    if {[info exists ::env(PATH)]} {
        if {$anonymize} {
            lappend info "PATH: <anonymized>"
        } else {
            lappend info "PATH: $::env(PATH)"
        }
    }
    return $info
}

# The environment variables that steer the search for packages and shared
# libraries, one entry per line (0.3). TCLLIBPATH is a Tcl list, the others
# use the platform's path separator. Unset variables are left out.
proc ::tclutils::tuappinfo::_collectSearchVars {anonymize} {
    set vars {}
    if {[info exists ::env(TCLLIBPATH)]} {
        lappend vars TCLLIBPATH
    }
    lappend vars {*}[lsort -dictionary \
        [array names ::env -regexp {^TCL[0-9]+_[0-9]+_TM_PATH$}]]
    foreach v {LD_LIBRARY_PATH DYLD_LIBRARY_PATH} {
        if {[info exists ::env($v)]} { lappend vars $v }
    }
    set info {}
    lappend info ""
    lappend info "--- Search variables ---"
    if {[llength $vars] == 0} {
        lappend info "  (none set)"
        return $info
    }
    foreach v $vars {
        set val $::env($v)
        if {$v eq "TCLLIBPATH"} {
            if {[catch {llength $val}]} {
                set parts [split $val]
            } else {
                set parts $val
            }
        } else {
            set parts [split $val [_pathSep]]
        }
        lappend info "$v:"
        foreach p $parts {
            if {$p eq ""} continue
            lappend info "  [_dirLine $p $anonymize]"
        }
    }
    return $info
}

proc ::tclutils::tuappinfo::_collectAutoPath {anonymize} {
    set info {}
    lappend info ""
    lappend info "--- auto_path ---"
    foreach p $::auto_path {
        lappend info [_dirLine $p $anonymize]
    }
    if {[info exists ::tcl_pkgPath]} {
        lappend info ""
        lappend info "--- tcl_pkgPath ---"
        foreach p $::tcl_pkgPath {
            lappend info [_dirLine $p $anonymize]
        }
    }
    return $info
}

# Where a loaded package came from: the file named by "source" or "load" in
# its "package ifneeded" script, "" when the script names none (built in,
# provided by another package) or the name is not literal (0.3).
proc ::tclutils::tuappinfo::_pkgOrigin {pkg ver} {
    if {[catch {package ifneeded $pkg $ver} script] || $script eq ""} {
        return ""
    }
    set re {(?:^|[\s;\[])(?:source(?:\s+-encoding\s+\S+)?|load)\s+("[^"]*"|\{[^\}]*\}|[^\s;\]]+)}
    if {![regexp $re $script -> p]} {
        return ""
    }
    set p [string trim $p "\"{}"]
    if {[string match {*[$[]*} $p]} {
        return ""
    }
    return $p
}

proc ::tclutils::tuappinfo::_collectPackages {anonymize} {
    set info {}
    lappend info ""
    lappend info "--- Loaded Packages ---"
    foreach pkg [lsort [package names]] {
        set ver [package provide $pkg]
        if {$ver eq ""} continue
        set from [_pkgOrigin $pkg $ver]
        if {$from ne ""} {
            set from [_showPath $from $anonymize]
        }
        lappend info [string trimright \
            [format "  %-32s %-10s %s" $pkg $ver $from]]
    }
    return $info
}

# Shared libraries in this interpreter (info loaded): which file was really
# loaded (0.3). An empty file name is a statically linked package.
proc ::tclutils::tuappinfo::_collectLibraries {anonymize} {
    set info {}
    lappend info ""
    lappend info "--- Loaded Libraries ---"
    set libs {}
    catch {set libs [info loaded]}
    if {[llength $libs] == 0} {
        lappend info "  (none)"
        return $info
    }
    foreach l [lsort -index 1 $libs] {
        lassign $l file prefix
        if {$file eq ""} {
            set file "(static)"
        } else {
            set file [_showPath $file $anonymize]
        }
        lappend info [format "  %-16s %s" $prefix $file]
    }
    return $info
}

proc ::tclutils::tuappinfo::_collectTmPaths {{anonymize 0}} {
    set info {}
    # tcl::tm::path is a command, not a variable -- query it via `path list`.
    if {[llength [::info commands ::tcl::tm::path]]} {
        lappend info ""
        lappend info "--- tm::path ---"
        foreach p [::tcl::tm::path list] {
            lappend info [_dirLine $p $anonymize]
        }
    }
    return $info
}

proc ::tclutils::tuappinfo::_collectLoadedTm {anonymize} {
    variable loadedTm
    set info {}
    lappend info ""
    lappend info "--- Loaded TM Modules ---"
    if {[llength $loadedTm] == 0} {
        lappend info "  (none tracked)"
    } else {
        foreach f $loadedTm {
            if {$anonymize} {
                lappend info "  <tm-[_hash $f]>.tm"
            } else {
                lappend info "  $f"
            }
        }
    }
    return $info
}

package provide tclutils::tuappinfo 0.3
