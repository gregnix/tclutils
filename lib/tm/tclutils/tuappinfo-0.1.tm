# tclutils::tuappinfo -- collect application / system information into a plain
# Description: collect Tcl/Tk, executable, platform and environment info into a plain text report
# Category: System · runtime
# text report: Tcl/Tk versions, executable, platform, selected environment,
# search paths, loaded packages, and optionally a list of explicitly tracked
# module files. Supports anonymisation of user/host/path data. Pure Tcl,
# library-neutral, no GUI (rendering is left to the caller).
#
# Tcl 8.6-
package require Tcl 8.6-

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
    array set opt $args
    set report {}
    lappend report {*}[_collectCoreInfo    $opt(-title) $opt(-anonymize)]
    lappend report {*}[_collectEnvironment             $opt(-anonymize)]
    lappend report {*}[_collectPackages]
    lappend report {*}[_collectTmPaths]
    lappend report {*}[_collectLoadedTm                $opt(-anonymize)]
    return [join $report "\n"]
}

# Write the report to a file (same options as buildReport).
proc ::tclutils::tuappinfo::writeLog {file args} {
    set txt [buildReport {*}$args]
    set fh [open $file w]
    puts $fh $txt
    close $fh
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

proc ::tclutils::tuappinfo::_maskPath {p home} {
    if {$home ne "" && [string match "$home*" $p]} {
        return "<HOME>[string range $p [string length $home] end]"
    }
    return $p
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
        lappend info "Tk version: $::tk_version"
    }
    lappend info "Executable: [info nameofexecutable]"
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
    set home ""
    if {[info exists ::env(HOME)]} { set home $::env(HOME) }
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

proc ::tclutils::tuappinfo::_collectTmPaths {} {
    set info {}
    # tcl::tm::path is a command, not a variable -- query it via `path list`.
    if {[llength [::info commands ::tcl::tm::path]]} {
        lappend info ""
        lappend info "--- tm::path ---"
        foreach p [::tcl::tm::path list] {
            lappend info "  $p"
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

package provide tclutils::tuappinfo 0.1
