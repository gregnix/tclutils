# tclutils::tuexe -- locate external executables
# Description: locate external executables
# Category: System · runtime
#
# Resolve a program by name across extra (bundled/vendor) directories and the
# system PATH, trying a list of candidate names and platform-specific
# extensions. Generalises the common "find gs / gswin64c / ... via auto_execok"
# idiom and adds bundled-binary directories. Pure Tcl, no dependencies.
#
#   tuexe::find {gs gswin64c gswin32c}          ;# -> /usr/bin/gs  (or "")
#   tuexe::find qpdf -dirs [list $vendorBin]    ;# bundled wins, then PATH
#   tuexe::find foo  -dirs $d -pathfirst 1      ;# PATH wins, then $d
#   tuexe::all  {python python3}                ;# every match, de-duplicated
#   tuexe::exists ffmpeg                         ;# -> 0/1
#
# By default bundled directories (-dirs) are searched before PATH so a shipped
# binary wins deterministically; pass -pathfirst 1 to prefer the system PATH.
# Error code: {TCLUTILS TUEXE OPTION}.

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tuexe {
    namespace export find all exists
}

# Executable extensions to try inside explicit directories. On Windows honour
# PATHEXT if set, else sensible defaults; on Unix none.
proc ::tclutils::tuexe::_exts {} {
    if {$::tcl_platform(platform) ne "windows"} { return {} }
    if {[info exists ::env(PATHEXT)] && $::env(PATHEXT) ne ""} {
        set out {}
        foreach e [split $::env(PATHEXT) ";"] {
            set e [string tolower [string trim $e]]
            if {$e ne ""} { lappend out $e }
        }
        if {[llength $out]} { return $out }
    }
    return {.exe .com .bat .cmd}
}

# Look for $name (and $name+ext) inside $dir; return a normalized path or "".
proc ::tclutils::tuexe::_inDir {dir name exts} {
    set win [expr {$::tcl_platform(platform) eq "windows"}]
    set cand [list [file join $dir $name]]
    foreach e $exts { lappend cand [file join $dir $name$e] }
    foreach c $cand {
        if {[file isfile $c] && ($win || [file executable $c])} {
            return [file normalize $c]
        }
    }
    return ""
}

# Look for $name on the system PATH via auto_execok; return a path or "".
proc ::tclutils::tuexe::_onPath {name} {
    set r [auto_execok $name]
    if {$r eq ""} { return "" }
    return [file normalize [lindex $r 0]]
}

# Resolve an executable. $names is one name or a list of candidate names.
#   -dirs {d ...}   extra directories to search (e.g. bundled vendor bin dirs)
#   -pathfirst 0|1  search PATH before -dirs (default 0: -dirs win)
#   -all 0|1        collect every match (de-duplicated) instead of the first
proc ::tclutils::tuexe::find {names args} {
    array set o {-dirs {} -pathfirst 0 -all 0}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error -errorcode {TCLUTILS TUEXE OPTION} \
                "unknown option '$k'"
        }
        set o($k) $v
    }
    set exts [_exts]
    set hits {}
    foreach name $names {
        set order {}
        if {$o(-pathfirst)} {
            lappend order path
            foreach d $o(-dirs) { lappend order [list dir $d] }
        } else {
            foreach d $o(-dirs) { lappend order [list dir $d] }
            lappend order path
        }
        foreach step $order {
            if {$step eq "path"} {
                set p [_onPath $name]
            } else {
                set p [_inDir [lindex $step 1] $name $exts]
            }
            if {$p ne ""} {
                if {!$o(-all)} { return $p }
                if {$p ni $hits} { lappend hits $p }
            }
        }
    }
    if {$o(-all)} { return $hits }
    return ""
}

# Every match (de-duplicated), in search order.
proc ::tclutils::tuexe::all {names args} {
    return [find $names {*}$args -all 1]
}

# 1 if any candidate resolves, else 0.
proc ::tclutils::tuexe::exists {names args} {
    return [expr {[find $names {*}$args] ne ""}]
}

package provide tclutils::tuexe 0.1
