# tclutils::tuterm -- ANSI terminal styling (SGR): text attributes and 16- /
# 256- / 24-bit colors, with a global enable switch (honours NO_COLOR), an ANSI
# stripper, and optional Windows VT-mode initialisation. Pure Tcl, GUI-free.
#
# API:
#   tuterm::style ?spec ...?     -> SGR escape sequence ("" when disabled)
#   tuterm::wrap  text ?spec ...? -> styled text + reset (plain text when disabled)
#   tuterm::off   attr           -> the "off" SGR for one attribute
#   tuterm::names ?what?         -> available attribute/color names
#   tuterm::strip text           -> text with all SGR sequences removed
#   tuterm::enable ?bool?        -> get/set the global enable flag
#   tuterm::auto                 -> set enable from the NO_COLOR convention
#   tuterm::enableVT / disableVT -> Windows console VT mode (no-op elsewhere)
#
# Specs accepted by style/wrap:
#   reset
#   bold dim italic underline blink reverse invisible strike   (bare = turn on)
#   bold:on bold:off ...                                        (explicit)
#   fg:<color> bg:<color>   color = name | 0..255 | #rrggbb
#     (fgcolor:/bgcolor: are accepted aliases)
#
# Tcl 8.6-
package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tuterm {
    namespace export style wrap off names strip enable auto enableVT disableVT
    variable enabled 1
    variable sgr [dict create \
        reset     \x1b\[0m \
        bold      [dict create on \x1b\[1m off \x1b\[22m] \
        dim       [dict create on \x1b\[2m off \x1b\[22m] \
        italic    [dict create on \x1b\[3m off \x1b\[23m] \
        underline [dict create on \x1b\[4m off \x1b\[24m] \
        blink     [dict create on \x1b\[5m off \x1b\[25m] \
        reverse   [dict create on \x1b\[7m off \x1b\[27m] \
        invisible [dict create on \x1b\[8m off \x1b\[28m] \
        strike    [dict create on \x1b\[9m off \x1b\[29m] \
        fgcolor   [dict create \
            black \x1b\[30m red \x1b\[31m green \x1b\[32m yellow \x1b\[33m \
            blue \x1b\[34m magenta \x1b\[35m cyan \x1b\[36m white \x1b\[37m \
            gray \x1b\[90m bright_black \x1b\[90m bright_red \x1b\[91m \
            bright_green \x1b\[92m bright_yellow \x1b\[93m bright_blue \x1b\[94m \
            bright_magenta \x1b\[95m bright_cyan \x1b\[96m bright_white \x1b\[97m] \
        bgcolor   [dict create \
            black \x1b\[40m red \x1b\[41m green \x1b\[42m yellow \x1b\[43m \
            blue \x1b\[44m magenta \x1b\[45m cyan \x1b\[46m white \x1b\[47m \
            gray \x1b\[100m bright_black \x1b\[100m bright_red \x1b\[101m \
            bright_green \x1b\[102m bright_yellow \x1b\[103m bright_blue \x1b\[104m \
            bright_magenta \x1b\[105m bright_cyan \x1b\[106m bright_white \x1b\[107m]]
}

proc ::tclutils::tuterm::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUTERM $reason] $msg
}

# Resolve a fg/bg color value (name | 0..255 | #rrggbb) to its SGR sequence.
proc ::tclutils::tuterm::_color {which value} {
    variable sgr
    set base [expr {$which eq "fg" ? 38 : 48}]
    if {[string is integer -strict $value] && $value >= 0 && $value <= 255} {
        return "\x1b\[${base};5;${value}m"
    } elseif {[regexp {^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$} \
                  $value -> rr gg bb]} {
        scan $rr %x r; scan $gg %x g; scan $bb %x b
        return "\x1b\[${base};2;${r};${g};${b}m"
    }
    set cat [expr {$which eq "fg" ? "fgcolor" : "bgcolor"}]
    if {[dict exists $sgr $cat $value]} { return [dict get $sgr $cat $value] }
    _err VALUE "unknown color \"$value\""
}

# Build an SGR escape sequence from style specs. Returns "" when disabled.
proc ::tclutils::tuterm::style {args} {
    variable enabled
    variable sgr
    if {!$enabled} { return "" }
    set out ""
    foreach a $args {
        if {$a eq "reset"} {
            append out [dict get $sgr reset]
        } elseif {[regexp {^([a-z]+):(.+)$} $a -> cat val]} {
            switch -- $cat {
                fg - fgcolor { append out [_color fg $val] }
                bg - bgcolor { append out [_color bg $val] }
                default {
                    if {[dict exists $sgr $cat] && [dict exists $sgr $cat $val]} {
                        append out [dict get $sgr $cat $val]
                    } else {
                        _err STYLE "unknown style \"$a\""
                    }
                }
            }
        } elseif {[dict exists $sgr $a] && [dict exists $sgr $a on]} {
            append out [dict get $sgr $a on]
        } else {
            _err STYLE "unknown style \"$a\""
        }
    }
    return $out
}

# Wrap text in the given style and a trailing reset (plain text when disabled).
proc ::tclutils::tuterm::wrap {text args} {
    variable enabled
    if {!$enabled} { return $text }
    return "[style {*}$args]$text[dict get $::tclutils::tuterm::sgr reset]"
}

# The "off" SGR for one attribute (e.g. off underline).
proc ::tclutils::tuterm::off {attr} {
    variable sgr
    if {[dict exists $sgr $attr off]} { return [dict get $sgr $attr off] }
    _err CATEGORY "no off code for \"$attr\""
}

# List names: all (top-level keys), fg|bg (colors), or one attribute's on/off.
proc ::tclutils::tuterm::names {{what all}} {
    variable sgr
    switch -- $what {
        all          { return [dict keys $sgr] }
        fg - fgcolor { return [dict keys [dict get $sgr fgcolor]] }
        bg - bgcolor { return [dict keys [dict get $sgr bgcolor]] }
        default {
            if {[dict exists $sgr $what]} { return [dict keys [dict get $sgr $what]] }
            return {}
        }
    }
}

# Remove all SGR escape sequences from text.
proc ::tclutils::tuterm::strip {text} {
    return [regsub -all {\x1b\[[0-9;]*m} $text ""]
}

# Get (no arg) or set (bool arg) the global enable flag.
proc ::tclutils::tuterm::enable {args} {
    variable enabled
    if {[llength $args]} { set enabled [expr {[lindex $args 0] ? 1 : 0}] }
    return $enabled
}

# Set the enable flag from the NO_COLOR convention (present => disable).
proc ::tclutils::tuterm::auto {} {
    variable enabled
    set enabled [expr {[info exists ::env(NO_COLOR)] ? 0 : 1}]
    return $enabled
}

# Enable Windows console VT processing (no-op / success on other platforms).
proc ::tclutils::tuterm::enableVT {} {
    if {$::tcl_platform(platform) ne "windows"} { return 1 }
    if {[catch {
        package require twapi
        set h [twapi::get_console_handle stdout]
        set mode [twapi::GetConsoleMode $h]
        twapi::SetConsoleMode $h [expr {$mode | 0x0004}]
    }]} { return 0 }
    return 1
}

# Disable Windows console VT processing (no-op / success on other platforms).
proc ::tclutils::tuterm::disableVT {} {
    if {$::tcl_platform(platform) ne "windows"} { return 1 }
    if {[catch {
        package require twapi
        set h [twapi::get_console_handle stdout]
        set mode [twapi::GetConsoleMode $h]
        twapi::SetConsoleMode $h [expr {$mode & ~0x0004}]
    }]} { return 0 }
    return 1
}

package provide tclutils::tuterm 0.1
