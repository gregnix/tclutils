# tclutils::tutail -- tail-like helpers
# Description: tail-like helpers
# Category: Text · strings/coreutils
package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tutail { namespace export text file }

proc ::tclutils::tutail::text {text {count 10}} {
    if {![string is integer -strict $count] || $count < 0} {
        return -code error "count must be a non-negative integer"
    }
    set lines [split $text \n]
    if {$count == 0} { return "" }
    return [join [lrange $lines end-[expr {$count - 1}] end] \n]
}

proc ::tclutils::tutail::file {path {count 10}} {
    if {![string is integer -strict $count] || $count < 0} {
        return -code error "count must be a non-negative integer"
    }
    if {$count == 0} { return "" }
    set f [open $path r]
    fconfigure $f -translation auto
    set buf {}
    while {[gets $f line] >= 0} {
        lappend buf $line
        if {[llength $buf] > $count} { set buf [lrange $buf end-[expr {$count - 1}] end] }
    }
    close $f
    return [join $buf \n]
}

package provide tclutils::tutail 0.1
