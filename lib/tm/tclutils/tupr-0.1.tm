# tclutils::tupr -- pr-like simple page formatting in pure Tcl
# Description: pr-like simple page formatting in pure Tcl
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tupr {
    namespace export text file
    variable version 0.1
}

# Build the 5-line page header: two blank lines, one info line
# (date, title, "Page N"), then two blank lines.
proc ::tclutils::tupr::_header {date title page width} {
    set right "Page $page"
    set left $date
    if {$title ne ""} { append left "   " $title }
    set pad [expr {$width - [string length $left] - [string length $right]}]
    if {$pad < 1} { set pad 1 }
    set info "$left[string repeat " " $pad]$right"
    return [list "" "" $info "" ""]
}

# Paginate a text into pages with headers. Options:
#   -length N    total lines per page (default 66; header+footer use 10)
#   -header S    title shown in the header (default empty)
#   -width N     page width for header layout (default 72)
#   -number 0|1  number body lines (default 0)
#   -date S      date string for the header (default: current date/time)
proc ::tclutils::tupr::text {text args} {
    set defaults [dict create -length 66 -header "" -width 72 -number 0 \
        -date [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set length [::tclutils::common::ensurePositiveInteger [dict get $opts -length] -length]
    set title  [dict get $opts -header]
    set width  [::tclutils::common::ensurePositiveInteger [dict get $opts -width] -width]
    set number [::tclutils::common::ensureBoolean [dict get $opts -number] -number]
    set date   [dict get $opts -date]

    set headerLines 5
    set footerLines 5
    set bodyPerPage [expr {$length - $headerLines - $footerLines}]
    if {$bodyPerPage < 1} {
        return -code error -errorcode {TCLUTILS TUPR LENGTH} \
            "page length $length is too small (needs more than [expr {$headerLines + $footerLines}] lines)"
    }

    set lines [::tclutils::common::splitLines $text]
    if {$number} {
        set numbered {}
        set ln 1
        foreach l $lines {
            lappend numbered [format "%5d\t%s" $ln $l]
            incr ln
        }
        set lines $numbered
    }

    set out {}
    set total [llength $lines]
    set page 1
    for {set i 0} {$i < $total} {incr i $bodyPerPage} {
        set chunk [lrange $lines $i [expr {$i + $bodyPerPage - 1}]]
        lappend out {*}[_header $date $title $page $width]
        lappend out {*}$chunk
        # pad the body to a full page, then add the footer blank lines
        for {set p [llength $chunk]} {$p < $bodyPerPage} {incr p} {
            lappend out ""
        }
        for {set f 0} {$f < $footerLines} {incr f} {
            lappend out ""
        }
        incr page
    }
    return [join $out \n]
}

proc ::tclutils::tupr::file {path args} {
    set data [::tclutils::common::readFile $path]
    set hasHeader 0
    foreach a $args { if {$a eq "-header"} { set hasHeader 1; break } }
    if {!$hasHeader} {
        lappend args -header [::file tail $path]
    }
    return [text $data {*}$args]
}

package provide tclutils::tupr 0.1
