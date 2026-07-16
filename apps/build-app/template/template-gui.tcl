#!/usr/bin/env wish
# _template (GUI) -- a starting point for a build-app-packageable Tk app.
#
# The numbered comments map to docs/guide/build-app-app-conventions.md.
# Build it with:
#   build-app -kind gui -out myapp -basekit basekit-tk \
#             -app _template -main template-gui.tcl \
#             -launch '::template::buildApp .'
# (add -tm <tree> for tclutils/tkutils modules, -extlib <root> for external ones)

package require Tcl 8.6-                              ;# (9) dash form: 8.6 and 9.x

namespace eval ::template {}

# (2) locate our own files relative to [info script], never via cwd/absolute.
set ::template::dir [file dirname [file normalize [info script]]]

# (4) bootstrap the module path via _lib/paths.tcl when present (repo layout /
#     the shim build-app writes into the image); harmless when absent.
set _bootstrap [file join $::template::dir .. _lib paths.tcl]
if {[file exists $_bootstrap]} { source $_bootstrap }
unset _bootstrap

# (3)(5) declare dependencies with `package require`, and gather hard external
#        drivers in one proc with a clear error. The prober sees these loads.
proc ::template::requireDeps {} {
    # package require tkutils                       ;# example module dependency
    # if {[catch {package require tdbc::sqlite3} e]} {
    #     error "This app needs tdbc::sqlite3.\n$e"
    # }
    return
}

# (6) write only to a user/home location -- the app's own directory is read-only
#     inside a zipkit.
proc ::template::confDir {} {
    set d [file join [file normalize ~] .config template-app]  ;# [file home] = 9.0 only
    file mkdir $d
    return $d
}

# (7) buildApp creates the widgets and RETURNS. No vwait/tkwait/mainloop here,
#     and no mandatory external connection at build time -- build-app's main.tcl
#     runs the event loop and adds a SMOKE branch for headless testing.
proc ::template::buildApp {parent} {
    set top [expr {$parent eq "." ? "" : $parent}]
    wm title . "Template App"

    # (2) resources live in the app dir and load relative to $::template::dir:
    # image create photo ::template::logo -file [file join $::template::dir res logo.png]

    ttk::frame $top.f -padding 12
    pack $top.f -fill both -expand 1
    ttk::label  $top.f.msg -text "Hello from the template."
    ttk::button $top.f.quit -text "Quit" -command {exit 0}
    pack $top.f.msg -pady {0 8}
    pack $top.f.quit
    return .
}

# (1) the argv0 guard builds the app when this script IS the main program
#     (e.g. `wish template-gui.tcl`). Inside a zipkit it does NOT fire, because
#     main.tcl sources this file -- so build-app is told the entry point with
#     -launch '::template::buildApp .'. When run directly, wish provides the
#     event loop after this script; nothing to do here.
if {[info exists argv0] && [file normalize $argv0] eq [file normalize [info script]]} {
    package require Tk 8.6-
    ::template::requireDeps
    ::template::buildApp .
}
