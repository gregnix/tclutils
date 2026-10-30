# tclutils::tuappinfo -- collect application / system information into a plain
# Description: collect Tcl/Tk, executable, platform and environment info into a plain text report
# Category: System · runtime
# text report: Tcl/Tk versions, executable, platform, selected environment,
# search paths, loaded packages, and optionally a list of explicitly tracked
# module files. Supports anonymisation of user/host/path data. Pure Tcl,
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
    set report {}
    lappend report {*}[_collectCoreInfo    $opt(-title) $opt(-anonymize)]
    lappend report {*}[_collectEnvironment             $opt(-anonymize)]
    lappend report {*}[_collectPackages]
    lappend report {*}[_collectTmPaths                 $opt(-anonymize)]
    lappend report {*}[_collectLoadedTm                $opt(-anonymize)]
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
        set same [expr {$nocase ? [string equal -nocase $head $home]
                                : [string equal $head $home]}]
        set next [string index $q $len]
        if {$same && ($next eq "" || $next eq "/")} {
            return "<HOME>[string range $q $len end]"
        }
    }
    set tail [lindex [split [string trimright $q /] /] end]
    return "<path>/$tail"
}

proc ::tclutils::tuappinfo::_collectCoreInfo {title anonymize} {
    set info {}
    lappend info "==== $title ===="
    lappend info "Timestamp: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
    lappend info "PID: [pid]"
    lappend info ""
    lappend info "--- Tcl / Tk ---"
    lappend info "Tcl version: [info patchlevel]"
    if {[info exists ::tk_version]} {
        # the patch level, as for Tcl (0.3; was tk_version, "9.0")
        lappend info "Tk version: [expr {[info exists ::tk_patchLevel] ? $::tk_patchLevel : $::tk_version}]"
    }
    if {$anonymize} {
        lappend info "Executable: [_maskPath [info nameofexecutable] [_home]]"
    } else {
        lappend info "Executable: [info nameofexecutable]"
    }
    lappend info "Platform: $::tcl_platform(os) $::tcl_platform(osVersion)"
    lappend info "Machine: $::tcl_platform(machine)"
    if {[info exists ::env(COMPUTERNAME)]} {
        if {$anonymize} {
            lappend info "Host: <host-[_hash $::env(COMPUTERNAME)]>"
        } else {
            lappend info "Host: $::env(COMPUTERNAME)"
        }
    }
    return $info
}

proc ::tclutils::tuappinfo::_collectEnvironment {anonymize} {
    set info {}
    lappend info ""
    lappend info "--- Environment ---"
    set home [_home]
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
    lappend info ""
    lappend info "--- auto_path ---"
    foreach p $::auto_path {
        if {$anonymize} {
            lappend info "  [_maskPath $p $home]"
        } else {
            lappend info "  $p"
        }
    }
    return $info
}

proc ::tclutils::tuappinfo::_collectPackages {} {
    set info {}
    lappend info ""
    lappend info "--- Loaded Packages ---"
    foreach pkg [lsort [package names]] {
        set ver [package provide $pkg]
        if {$ver ne ""} {
            lappend info [format "  %-32s %s" $pkg $ver]
        }
    }
    return $info
}

proc ::tclutils::tuappinfo::_collectTmPaths {{anonymize 0}} {
    set info {}
    set home [_home]
    # tcl::tm::path is a command, not a variable -- query it via `path list`.
    if {[llength [::info commands ::tcl::tm::path]]} {
        lappend info ""
        lappend info "--- tm::path ---"
        foreach p [::tcl::tm::path list] {
            if {$anonymize} {
                lappend info "  [_maskPath $p $home]"
            } else {
                lappend info "  $p"
            }
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
