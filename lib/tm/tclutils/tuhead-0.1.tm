# tclutils::tuhead -- head-like helpers
package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tuhead { namespace export text file }

proc ::tclutils::tuhead::text {text {count 10}} {
    if {![string is integer -strict $count] || $count < 0} {
        return -code error "count must be a non-negative integer"
    }
    set lines [split $text \n]
    return [join [lrange $lines 0 [expr {$count - 1}]] \n]
}

proc ::tclutils::tuhead::file {path {count 10}} {
    if {![string is integer -strict $count] || $count < 0} {
        return -code error "count must be a non-negative integer"
    }
    set f [open $path r]
    fconfigure $f -translation auto
    set out {}
    set n 0
    while {$n < $count && [gets $f line] >= 0} {
        lappend out $line
        incr n
    }
    close $f
    return [join $out \n]
}

package provide tclutils::tuhead 0.1
