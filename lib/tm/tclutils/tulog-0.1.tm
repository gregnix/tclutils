# tclutils::tulog -- a small, dependency-free leveled logger. Pure Tcl, 8.6+/9.x.
# Description: a small, dependency-free leveled logger. Pure Tcl, 8.6+/9.x.
# Category: System · runtime
#
# A logger is a callable command object (so the level names "info"/"error" are
# subcommands, not procs that would shadow the Tcl built-ins):
#
#   set log [::tclutils::tulog::new -name app -level info -channel stderr]
#   $log info  "starting up"
#   $log debug "x = $x"          ;# suppressed while level is info
#   $log warn  "low disk"
#   $log error "request failed"
#   $log log info "same as: \$log info ..."
#   $log setLevel debug          ;# raise verbosity
#   $log level                   ;# -> debug
#   $log destroy
#
# Levels (increasing severity): debug < info < warn < error. A message is
# emitted only when its level is at least the logger's current level.
#
# ::tclutils::tulog::assert evaluates a condition in the caller's scope and
# raises {TCLUTILS TULOG ASSERT} if it is false -- handy for debug-time checks.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tulog {
    namespace export new assert
    variable seq 0
    variable state
    array set state {}
    variable order {debug 10 info 20 warn 30 error 40}
    variable version 0.1
}

proc ::tclutils::tulog::_levelValue {level} {
    variable order
    if {![dict exists $order $level]} {
        return -code error -errorcode {TCLUTILS TULOG LEVEL} \
            "unknown level \"$level\": use debug, info, warn or error"
    }
    return [dict get $order $level]
}

# Create a logger. Options: -channel (default stderr), -level (default info),
# -name (prefix, default ""), -timestamp (default 1). Returns a command.
proc ::tclutils::tulog::new {args} {
    variable seq
    variable state
    set opts [::tclutils::common::parseOptions \
        {-channel stderr -level info -name "" -timestamp 1} {*}$args]
    _levelValue [dict get $opts -level]
    set tok "::tclutils::tulog::logger[incr seq]"
    set state($tok,channel)   [dict get $opts -channel]
    set state($tok,level)     [dict get $opts -level]
    set state($tok,name)      [dict get $opts -name]
    set state($tok,timestamp) [::tclutils::common::ensureBoolean \
        [dict get $opts -timestamp] -timestamp]
    interp alias {} $tok {} ::tclutils::tulog::_dispatch $tok
    return $tok
}

proc ::tclutils::tulog::_dispatch {tok sub args} {
    variable state
    switch -- $sub {
        debug - info - warn - error {
            if {[llength $args] != 1} {
                return -code error "wrong # args: should be \"$tok $sub message\""
            }
            _emit $tok $sub [lindex $args 0]
        }
        log {
            if {[llength $args] != 2} {
                return -code error "wrong # args: should be \"$tok log level message\""
            }
            _emit $tok [lindex $args 0] [lindex $args 1]
        }
        setLevel {
            set lvl [lindex $args 0]
            _levelValue $lvl
            set state($tok,level) $lvl
            return
        }
        level   { return $state($tok,level) }
        destroy {
            interp alias {} $tok {}
            array unset state $tok,*
            return
        }
        default {
            return -code error "unknown subcommand \"$sub\": must be\
                debug, info, warn, error, log, setLevel, level or destroy"
        }
    }
}

proc ::tclutils::tulog::_now {} {
    return [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
}

proc ::tclutils::tulog::_emit {tok level msg} {
    variable state
    if {[_levelValue $level] < [_levelValue $state($tok,level)]} { return }
    set line ""
    if {$state($tok,timestamp)} { append line "[_now] " }
    append line "\[[string toupper $level]\]"
    if {$state($tok,name) ne ""} { append line " $state($tok,name)" }
    append line ": $msg"
    puts $state($tok,channel) $line
    catch {flush $state($tok,channel)}
    return
}

# Evaluate exprStr in the caller's scope; raise {TCLUTILS TULOG ASSERT} if false.
proc ::tclutils::tulog::assert {exprStr {msg ""}} {
    if {![uplevel 1 [list expr $exprStr]]} {
        if {$msg eq ""} { set msg "assertion failed: $exprStr" }
        return -code error -errorcode {TCLUTILS TULOG ASSERT} $msg
    }
    return
}

package provide tclutils::tulog 0.1
