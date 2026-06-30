# setup.tcl -- make the tclutils / tkutils module libraries discoverable.
#
# Source this once from your own application, then `package require` the
# modules; no environment setup is needed when the libraries sit in one of the
# standard locations:
#
#     source /path/to/tkutils/tools/setup.tcl     ;# or .../tclutils/tools/setup.tcl
#     package require tclutils::tubin
#     package require tkutils::tkucsv
#
# The file is identical in both packages -- sourcing either one makes BOTH
# libraries discoverable (tkutils depends on tclutils). It is the single source
# of truth for path resolution; the bundled apps reach it through the thin
# wrapper apps/_lib/paths.tcl.
#
# For each package the resolver tries the locations below, in priority order,
# and adds only the ones that exist. A genuinely missing package then surfaces
# loudly via `package require` -- that is the intended signal, not this file.
#
#   1. TCLUTILS_TM / TKUTILS_TM                          explicit override (wins)
#   2. <this-repo>/lib/tm                                the package this file ships in
#   3. <tcl-install>/<pkg>/lib/tm                        next to the Tcl library
#   4. /usr/local/share/tcltk/<pkg>/lib/tm               system-wide share (Unix)
#   5. $XDG_DATA_HOME|~/.local/share/tcltk/<pkg>/lib/tm  per-user (XDG)
#   6. <holder>/<pkg>/lib/tm                             side-by-side, unversioned
#   7. <holder>/<pkg>-*/lib/tm                           side-by-side, versioned (highest)
#
# "<holder>" is a directory that may contain the sibling library folders. Both
# the in-package layout (<repo>/tools/setup.tcl, holder = parent of <repo>) and
# a loose placement (setup.tcl dropped directly next to the library folders)
# are handled.

namespace eval ::tkupaths {}

proc ::tkupaths::add {} {
    set self [file dirname [file normalize [info script]]]
    set repo [file dirname $self]                  ;# in-package: <repo>/tools -> <repo>

    # directories that may hold the sibling library folders
    set holders [lsort -unique [list [file dirname $repo] $self]]

    set tcllib [file dirname [info library]]
    if {[info exists ::env(XDG_DATA_HOME)] && $::env(XDG_DATA_HOME) ne ""} {
        set xdg $::env(XDG_DATA_HOME)
    } elseif {[info exists ::env(HOME)]} {
        set xdg [file join $::env(HOME) .local share]
    } else {
        set xdg ""
    }

    foreach pkg {tclutils tkutils} ev {TCLUTILS_TM TKUTILS_TM} {
        # candidates in priority order; added in reverse so the override ends
        # up at the head of the module path
        set cands {}
        if {[info exists ::env($ev)] && $::env($ev) ne ""} {
            lappend cands $::env($ev)
        }
        lappend cands [file join $repo lib tm]
        lappend cands [file join $tcllib $pkg lib tm]
        lappend cands [file join / usr local share tcltk $pkg lib tm]
        if {$xdg ne ""} { lappend cands [file join $xdg tcltk $pkg lib tm] }
        foreach h $holders {
            lappend cands [file join $h $pkg lib tm]
            # highest versioned sibling <pkg>-*/lib/tm, if any
            foreach d [lsort -decreasing -dictionary \
                    [glob -nocomplain -directory $h -type d ${pkg}-*]] {
                set vtm [file join $d lib tm]
                if {[file isdirectory $vtm]} { lappend cands $vtm; break }
            }
        }

        foreach d [lreverse $cands] {
            if {[file isdirectory $d] && $d ni [::tcl::tm::path list]} {
                ::tcl::tm::path add $d
            }
        }
    }
}

::tkupaths::add
