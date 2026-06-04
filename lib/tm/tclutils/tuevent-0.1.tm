# tclutils::tuevent -- a small publish/subscribe event bus.
# Create independent bus tokens, subscribe command prefixes to named events,
# and emit events with arguments. Pure Tcl. Tcl 8.6+ and 9.x.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuevent {
    namespace export create subscribe unsubscribe emit handlers events clear destroy
    variable state
    variable seq 0
}

proc ::tclutils::tuevent::_check {bus} {
    variable state
    if {![info exists state($bus)]} {
        return -code error -errorcode {TCLUTILS TUEVENT BUS} \
            "unknown event bus: \"$bus\""
    }
}

# Create a new bus; returns its token.
proc ::tclutils::tuevent::create {} {
    variable state
    variable seq
    set bus "tuevent[incr seq]"
    set state($bus) 1
    return $bus
}

# Subscribe a command prefix to an event (idempotent per handler).
proc ::tclutils::tuevent::subscribe {bus event handler} {
    variable state
    _check $bus
    set key $bus,sub,$event
    if {![info exists state($key)]} { set state($key) {} }
    if {$handler ni $state($key)} { lappend state($key) $handler }
    return
}

# Remove a previously subscribed handler.
proc ::tclutils::tuevent::unsubscribe {bus event handler} {
    variable state
    _check $bus
    set key $bus,sub,$event
    if {[info exists state($key)]} {
        set state($key) [lsearch -inline -all -not -exact $state($key) $handler]
        if {$state($key) eq ""} { unset state($key) }
    }
    return
}

# Emit an event; each handler is called at the global level with the event's
# arguments appended. Returns the number of handlers invoked. Handlers run in
# subscription order; a handler error propagates to the caller.
proc ::tclutils::tuevent::emit {bus event args} {
    variable state
    _check $bus
    set key $bus,sub,$event
    if {![info exists state($key)]} { return 0 }
    set n 0
    foreach handler $state($key) {
        uplevel #0 [list {*}$handler {*}$args]
        incr n
    }
    return $n
}

# List the handlers subscribed to an event.
proc ::tclutils::tuevent::handlers {bus event} {
    variable state
    _check $bus
    set key $bus,sub,$event
    if {[info exists state($key)]} { return $state($key) }
    return {}
}

# List the events that currently have subscribers.
proc ::tclutils::tuevent::events {bus} {
    variable state
    _check $bus
    set out {}
    foreach k [array names state $bus,sub,*] {
        lappend out [string range $k [string length $bus,sub,] end]
    }
    return [lsort $out]
}

# Remove all handlers for one event, or for the whole bus when event is "".
proc ::tclutils::tuevent::clear {bus {event ""}} {
    variable state
    _check $bus
    if {$event eq ""} {
        foreach k [array names state $bus,sub,*] { unset state($k) }
    } else {
        unset -nocomplain state($bus,sub,$event)
    }
    return
}

# Destroy a bus and all its subscriptions.
proc ::tclutils::tuevent::destroy {bus} {
    variable state
    _check $bus
    foreach k [array names state $bus,*] { unset state($k) }
    unset state($bus)
    return
}

package provide tclutils::tuevent 0.1
