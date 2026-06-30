# tclutils::tuxargs -- xargs-like list batching helpers
# Description: xargs-like list batching helpers
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuxargs {
    namespace export batches apply command
    variable version 0.1
}

proc ::tclutils::tuxargs::batches {items args} {
    set opts [::tclutils::common::parseOptions {-n 100 -skipempty 1} {*}$args]
    set n [::tclutils::common::ensurePositiveInteger [dict get $opts -n] -n]
    set skipempty [::tclutils::common::ensureBoolean [dict get $opts -skipempty] -skipempty]
    if {$skipempty} {
        set filtered {}
        foreach item $items {
            if {$item ne ""} { lappend filtered $item }
        }
        set items $filtered
    }
    set result {}
    set current {}
    foreach item $items {
        lappend current $item
        if {[llength $current] >= $n} {
            lappend result $current
            set current {}
        }
    }
    if {[llength $current] > 0} { lappend result $current }
    return $result
}

proc ::tclutils::tuxargs::apply {items commandPrefix args} {
    set opts [::tclutils::common::parseOptions {-n 100 -collect 1 -skipempty 1} {*}$args]
    set collect [::tclutils::common::ensureBoolean [dict get $opts -collect] -collect]
    set result {}
    foreach batch [batches $items -n [dict get $opts -n] -skipempty [dict get $opts -skipempty]] {
        set r [{*}$commandPrefix {*}$batch]
        if {$collect} { lappend result $r }
    }
    return $result
}

proc ::tclutils::tuxargs::command {items commandPrefix args} {
    tailcall apply $items $commandPrefix {*}$args
}

package provide tclutils::tuxargs 0.1
