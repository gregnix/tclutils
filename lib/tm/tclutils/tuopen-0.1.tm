# tclutils::tuopen -- open a URL or file path with the operating system's
# default application (xdg-open / open / cmd start). Pure Tcl. Tcl 8.6+ and 9.x.
#
# "launch" runs the opener detached; "command" returns the command that would
# be run (so callers/tests can inspect it without launching anything).

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuopen {
    namespace export launch command
    variable version 0.1
}

# Build the opener command for $target. Options -platform (windows/unix) and
# -os override the autodetected $tcl_platform values (mainly for testing).
proc ::tclutils::tuopen::command {target args} {
    if {[string trim $target] eq ""} {
        return -code error -errorcode {TCLUTILS TUOPEN TARGET} "empty target"
    }
    set opts [::tclutils::common::parseOptions {-platform "" -os ""} {*}$args]
    set plat [dict get $opts -platform]
    if {$plat eq ""} { set plat $::tcl_platform(platform) }
    set os [dict get $opts -os]
    if {$os eq ""} { set os $::tcl_platform(os) }

    switch -- $plat {
        windows { return [list cmd.exe /c start "" $target] }
        default {
            if {[string match -nocase *darwin* $os]} { return [list open $target] }
            return [list xdg-open $target]
        }
    }
}

# Open $target with the default application (runs detached). Returns the command
# that was launched. Errors with {TCLUTILS TUOPEN LAUNCH} if the opener fails.
proc ::tclutils::tuopen::launch {target args} {
    set cmd [command $target {*}$args]
    if {[catch {exec {*}$cmd &} err]} {
        return -code error -errorcode {TCLUTILS TUOPEN LAUNCH} \
            "cannot open \"$target\": $err"
    }
    return $cmd
}

# Build the editor command for $target. Options -platform, -os (as above) and
# -editor (explicit editor command, possibly multiple words). Without -editor:
# notepad on Windows, "open -e" on macOS, $EDITOR (else xdg-open) on Unix.
proc ::tclutils::tuopen::editCommand {target args} {
    if {[string trim $target] eq ""} {
        return -code error -errorcode {TCLUTILS TUOPEN TARGET} "empty target"
    }
    set opts [::tclutils::common::parseOptions {-platform "" -os "" -editor ""} {*}$args]
    set plat [dict get $opts -platform]
    if {$plat eq ""} { set plat $::tcl_platform(platform) }
    set os [dict get $opts -os]
    if {$os eq ""} { set os $::tcl_platform(os) }
    set editor [dict get $opts -editor]
    if {$editor ne ""} { return [list {*}$editor $target] }

    switch -- $plat {
        windows { return [list notepad $target] }
        default {
            if {[string match -nocase *darwin* $os]} { return [list open -e $target] }
            if {[info exists ::env(EDITOR)] && $::env(EDITOR) ne ""} {
                return [list {*}$::env(EDITOR) $target]
            }
            return [list xdg-open $target]
        }
    }
}

# Open $target in a text editor (runs detached). Returns the command launched.
proc ::tclutils::tuopen::edit {target args} {
    set cmd [editCommand $target {*}$args]
    if {[catch {exec {*}$cmd &} err]} {
        return -code error -errorcode {TCLUTILS TUOPEN LAUNCH} \
            "cannot edit \"$target\": $err"
    }
    return $cmd
}

# If $target is an existing file, return its containing directory, else $target.
proc ::tclutils::tuopen::_dirTarget {target} {
    if {[file exists $target] && [file isfile $target]} {
        return [file dirname $target]
    }
    return $target
}

# Open a directory in the OS file manager. If given a file, opens its folder.
proc ::tclutils::tuopen::openDir {target args} {
    return [launch [_dirTarget $target] {*}$args]
}

# --- per-user configuration paths --------------------------------------

proc ::tclutils::tuopen::_home {} {
    if {[info exists ::env(HOME)] && $::env(HOME) ne ""} { return $::env(HOME) }
    return [file normalize ~]
}

# Per-user configuration directory for an application.
#   Windows: %APPDATA%\<app>   macOS: ~/Library/Application Support/<app>
#   Unix:    $XDG_CONFIG_HOME/<app>  (else ~/.config/<app>)
# Options -platform, -os override the autodetected values (for testing).
proc ::tclutils::tuopen::configDir {app args} {
    if {[string trim $app] eq ""} {
        return -code error -errorcode {TCLUTILS TUOPEN APP} "empty application name"
    }
    set opts [::tclutils::common::parseOptions {-platform "" -os ""} {*}$args]
    set plat [dict get $opts -platform]
    if {$plat eq ""} { set plat $::tcl_platform(platform) }
    set os [dict get $opts -os]
    if {$os eq ""} { set os $::tcl_platform(os) }

    switch -- $plat {
        windows {
            if {[info exists ::env(APPDATA)] && $::env(APPDATA) ne ""} {
                set base $::env(APPDATA)
            } elseif {[info exists ::env(USERPROFILE)]} {
                set base [file join $::env(USERPROFILE) AppData Roaming]
            } else {
                set base [file join [_home] AppData Roaming]
            }
            return [file join $base $app]
        }
        default {
            if {[string match -nocase *darwin* $os]} {
                return [file join [_home] Library "Application Support" $app]
            }
            if {[info exists ::env(XDG_CONFIG_HOME)] && $::env(XDG_CONFIG_HOME) ne ""} {
                return [file join $::env(XDG_CONFIG_HOME) $app]
            }
            return [file join [_home] .config $app]
        }
    }
}

# Full path to a named file inside the application's config directory.
proc ::tclutils::tuopen::configFile {app filename args} {
    return [file join [configDir $app {*}$args] $filename]
}

package provide tclutils::tuopen 0.1
