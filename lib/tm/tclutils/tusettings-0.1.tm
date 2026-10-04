# tclutils::tusettings -- per-user settings, standard directories, recent files
# Description: per-user settings (INI) in the platform's config directory, standard dirs, recent-files list
# Category: System · runtime
#
# Every app used to find its own config directory (XDG, APPDATA, ...) and its
# own temp directory, and the editors each kept their own recent-files list.
# This module does it once:
#
#   tusettings::dir config myapp            ;# ~/.config/myapp, %APPDATA%\myapp, ...
#   set s [tusettings::load myapp -defaults {window {width 800}}]
#   dict set s window width 1024
#   tusettings::save myapp $s               ;# temp file + rename, never half-written
#   tusettings::value $s window width 800   ;# read with a fallback
#   tusettings::recentAdd myapp $file       ;# most recent first, no duplicates
#   tusettings::recentList myapp -existing 1
#
# Settings are a dict section -> (dict key -> value), stored as INI through
# tclutils::tuini: readable and editable by hand. Keys before any [section]
# live in section "". Comments in the file are not kept when the app saves.
#
# Directories (KIND config | cache | data | temp), each with APP appended:
#   Linux/BSD  $XDG_CONFIG_HOME|~/.config  $XDG_CACHE_HOME|~/.cache
#              $XDG_DATA_HOME|~/.local/share  $TMPDIR|/tmp
#   Windows    %APPDATA%  %LOCALAPPDATA%  %APPDATA%  %TEMP%|%TMP%
#   macOS      ~/Library/Application Support  ~/Library/Caches
#              ~/Library/Application Support  $TMPDIR|/tmp
#
# Unknown options: {TCLUTILS COMMON OPTION <opt>}.
# Errors: {TCLUTILS TUSETTINGS <REASON>}, REASON in
#   APP (bad app name), KIND, SYNTAX (unreadable INI), VALUE (cannot be
#   written as INI: newline in a value, bad key or section).
#
# Pure Tcl, no Tk. Tcl 8.6+ and 9.x.

package require Tcl 8.6-
package require tclutils::tuini 0.1
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tusettings {
    namespace export dir file load save value \
        recentAdd recentList recentRemove recentClear
    variable version 0.1
    # test hook: "" = detect; else unix | windows | macos
    variable platform ""
}

proc ::tclutils::tusettings::_platform {} {
    variable platform
    if {$platform ne ""} { return $platform }
    if {$::tcl_platform(platform) eq "windows"} { return windows }
    if {$::tcl_platform(os) eq "Darwin"} { return macos }
    return unix
}

# Home directory without tilde expansion (gone in Tcl 9).
proc ::tclutils::tusettings::_home {} {
    if {![catch {::file home} h]} { return $h }      ;# Tcl 9
    foreach v {HOME USERPROFILE} {
        if {[info exists ::env($v)] && $::env($v) ne ""} { return $::env($v) }
    }
    return [::file normalize ~]                      ;# Tcl 8.6
}

proc ::tclutils::tusettings::_env {name {fallback ""}} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $fallback
}

proc ::tclutils::tusettings::_checkApp {app} {
    if {$app eq "" || [regexp {[/\\:*?"<>|]} $app] || $app in {. ..}} {
        return -code error -errorcode {TCLUTILS TUSETTINGS APP} \
            "bad app name \"$app\": must be a plain directory name"
    }
}

# Directory of KIND for APP. -create 1 creates it.
proc ::tclutils::tusettings::dir {kind app args} {
    _checkApp $app
    set opts [::tclutils::common::parseOptions {-create 0} {*}$args]
    set home [_home]
    switch -- [_platform] {
        windows {
            set roaming [_env APPDATA [::file join $home AppData Roaming]]
            set local   [_env LOCALAPPDATA [::file join $home AppData Local]]
            set tmp     [_env TEMP [_env TMP [::file join $local Temp]]]
            set base [dict create config $roaming data $roaming \
                cache $local temp $tmp]
        }
        macos {
            set sup [::file join $home Library "Application Support"]
            set base [dict create config $sup data $sup \
                cache [::file join $home Library Caches] \
                temp [_env TMPDIR /tmp]]
        }
        default {
            set base [dict create \
                config [_env XDG_CONFIG_HOME [::file join $home .config]] \
                cache  [_env XDG_CACHE_HOME [::file join $home .cache]] \
                data   [_env XDG_DATA_HOME [::file join $home .local share]] \
                temp   [_env TMPDIR /tmp]]
        }
    }
    if {![dict exists $base $kind]} {
        return -code error -errorcode {TCLUTILS TUSETTINGS KIND} \
            "bad kind \"$kind\": must be config, cache, data or temp"
    }
    set d [::file join [dict get $base $kind] $app]
    if {[dict get $opts -create]} { ::file mkdir $d }
    return $d
}

# Path of the settings file: <config dir>/<name>.ini (name default "settings").
proc ::tclutils::tusettings::file {app {name settings}} {
    return [::file join [dir config $app] $name.ini]
}

# Settings of APP merged over -defaults (both section -> key -> value).
# A missing file gives the defaults. An unreadable file raises SYNTAX and
# names the file -- the caller decides whether to fall back.
proc ::tclutils::tusettings::load {app args} {
    set opts [::tclutils::common::parseOptions {-defaults {} -name settings} {*}$args]
    set result [dict get $opts -defaults]
    set f [file $app [dict get $opts -name]]
    if {![::file exists $f]} { return $result }
    set fh [open $f r]
    fconfigure $fh -encoding utf-8
    set text [read $fh]
    close $fh
    if {[catch {::tclutils::tuini::parse $text} data]} {
        return -code error -errorcode {TCLUTILS TUSETTINGS SYNTAX} \
            "$f: $data"
    }
    dict for {sec kv} $data {
        dict for {k v} $kv { dict set result $sec $k $v }
    }
    return $result
}

# Write SETTINGS for APP. Written to a temp file next to the target, then
# renamed over it, so a crash never leaves a half-written file.
proc ::tclutils::tusettings::save {app settings args} {
    set opts [::tclutils::common::parseOptions {-name settings} {*}$args]
    dict for {sec kv} $settings {
        if {[regexp {[\]\n\r]} $sec]} {
            return -code error -errorcode {TCLUTILS TUSETTINGS VALUE} \
                "section \"$sec\" cannot be written as INI"
        }
        dict for {k v} $kv {
            if {$k eq "" || [regexp {[=\n\r]} $k]
                    || [string index $k 0] in {; # [}
                    || [string trim $k] ne $k} {
                return -code error -errorcode {TCLUTILS TUSETTINGS VALUE} \
                    "key \"$k\" in \[$sec\] cannot be written as INI"
            }
            if {[regexp {[\n\r]} $v] || [string trim $v] ne $v} {
                return -code error -errorcode {TCLUTILS TUSETTINGS VALUE} \
                    "value of $sec.$k: no line breaks or outer blanks in INI"
            }
        }
    }
    set f [file $app [dict get $opts -name]]
    ::file mkdir [::file dirname $f]
    set tmp "$f.tmp[pid]"
    set fh [open $tmp w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh [::tclutils::tuini::toIni $settings]
    close $fh
    ::file rename -force $tmp $f
    return $f
}

# Read SECTION/KEY from a settings dict, DEFAULT if absent.
proc ::tclutils::tusettings::value {settings section key {default ""}} {
    if {[dict exists $settings $section $key]} {
        return [dict get $settings $section $key]
    }
    return $default
}

# ---------------------------------------------------------------------------
# Recent files: <config dir>/<list>.txt, one path per line, most recent first.
# ---------------------------------------------------------------------------

proc ::tclutils::tusettings::_recentFile {app list} {
    return [::file join [dir config $app] $list.txt]
}

proc ::tclutils::tusettings::_same {a b} {
    if {[_platform] eq "windows"} { return [string equal -nocase $a $b] }
    return [string equal $a $b]
}

proc ::tclutils::tusettings::_recentWrite {app list paths} {
    set f [_recentFile $app $list]
    ::file mkdir [::file dirname $f]
    set tmp "$f.tmp[pid]"
    set fh [open $tmp w]
    fconfigure $fh -encoding utf-8
    foreach p $paths { puts $fh $p }
    close $fh
    ::file rename -force $tmp $f
}

# The list, most recent first. -existing 1 drops paths that are gone.
proc ::tclutils::tusettings::recentList {app args} {
    set opts [::tclutils::common::parseOptions {-list recent -existing 0} {*}$args]
    set f [_recentFile $app [dict get $opts -list]]
    if {![::file exists $f]} { return {} }
    set fh [open $f r]
    fconfigure $fh -encoding utf-8
    set out {}
    foreach line [split [read $fh] \n] {
        set line [string trimright $line \r]
        if {$line eq ""} continue
        if {[dict get $opts -existing] && ![::file exists $line]} continue
        lappend out $line
    }
    close $fh
    return $out
}

# Put PATH (normalized) at the top; drops an older entry for the same file
# and keeps at most -max entries (10). Returns the new list.
proc ::tclutils::tusettings::recentAdd {app path args} {
    set opts [::tclutils::common::parseOptions {-list recent -max 10} {*}$args]
    set max [dict get $opts -max]
    if {![string is integer -strict $max] || $max < 1} {
        return -code error -errorcode {TCLUTILS TUSETTINGS VALUE} \
            "-max must be a positive integer, not \"$max\""
    }
    set path [::file normalize $path]
    if {[regexp {[\n\r]} $path]} {
        return -code error -errorcode {TCLUTILS TUSETTINGS VALUE} \
            "path with a line break cannot be stored"
    }
    set list [dict get $opts -list]
    set new [list $path]
    foreach p [recentList $app -list $list] {
        if {![_same $p $path]} { lappend new $p }
    }
    set new [lrange $new 0 [expr {[dict get $opts -max] - 1}]]
    _recentWrite $app $list $new
    return $new
}

proc ::tclutils::tusettings::recentRemove {app path args} {
    set opts [::tclutils::common::parseOptions {-list recent} {*}$args]
    set path [::file normalize $path]
    set list [dict get $opts -list]
    set new {}
    foreach p [recentList $app -list $list] {
        if {![_same $p $path]} { lappend new $p }
    }
    _recentWrite $app $list $new
    return $new
}

proc ::tclutils::tusettings::recentClear {app args} {
    set opts [::tclutils::common::parseOptions {-list recent} {*}$args]
    set f [_recentFile $app [dict get $opts -list]]
    ::file delete -- $f
    return
}

package provide tclutils::tusettings 0.1
