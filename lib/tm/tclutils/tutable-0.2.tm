# tclutils::tutable -- render a text table from headers + rows. Two styles:
# Description: render a text table from headers + rows.
# Category: Text · strings/coreutils
# markdown (GitHub-style pipe table, default) and box (ASCII +/-/| borders).
# Per-column alignment is supported. Pure Tcl; uses tclutils::common for option
# parsing. Distinct from tucolumn (the `column` coreutil filter).
#
#   tutable::render {Name Age} {{Alice 30} {Bob 7}}
#   tutable::render {Item Qty} {{Apples 12} {Pears 3}} -align {l r} -style box
#
# Rows may be ragged: missing trailing cells render as empty. A row with more
# cells than headers is an error ({TCLUTILS TUTABLE COLUMNS}), as is an empty
# header list ({TCLUTILS TUTABLE HEADERS}). In markdown every column is at
# least three characters wide, as wide as its separator cell.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tutable {
    namespace export render
    variable version 0.2
}

proc ::tclutils::tutable::_pad {s width a} {
    set n [expr {$width - [string length $s]}]
    if {$n <= 0} { return $s }
    switch -- $a {
        r { return "[string repeat { } $n]$s" }
        c {
            set l [expr {$n / 2}]
            set r [expr {$n - $l}]
            return "[string repeat { } $l]$s[string repeat { } $r]"
        }
        default { return "$s[string repeat { } $n]" }
    }
}

proc ::tclutils::tutable::_alignAt {align i} {
    set a [lindex $align $i]
    if {$a eq ""} { set a l }
    if {$a ni {l r c}} {
        return -code error -errorcode {TCLUTILS TUTABLE OPT} \
            "alignment must be l, r or c"
    }
    return $a
}

proc ::tclutils::tutable::render {headers rows args} {
    set o [::tclutils::common::parseOptions {-align {} -style markdown} {*}$args]
    set align [dict get $o -align]
    set style [dict get $o -style]
    if {$style ni {markdown box}} {
        return -code error -errorcode {TCLUTILS TUTABLE OPT} \
            "style must be markdown or box"
    }
    set ncol [llength $headers]
    if {$ncol == 0} {
        return -code error -errorcode {TCLUTILS TUTABLE HEADERS} \
            "headers must not be empty"
    }
    set r 0
    foreach row $rows {
        incr r
        if {[llength $row] > $ncol} {
            return -code error -errorcode {TCLUTILS TUTABLE COLUMNS} \
                "row $r has [llength $row] cells, but there are $ncol headers"
        }
    }

    # column widths from headers and all (possibly ragged) rows; markdown
    # columns are at least 3 wide so the cells line up with ":--"
    set min [expr {$style eq "markdown" ? 3 : 0}]
    set w {}
    foreach h $headers { lappend w [expr {max([string length $h], $min)}] }
    foreach row $rows {
        for {set i 0} {$i < $ncol} {incr i} {
            set len [string length [lindex $row $i]]
            if {$len > [lindex $w $i]} { lset w $i $len }
        }
    }

    set out {}
    if {$style eq "markdown"} {
        set cells {}
        for {set i 0} {$i < $ncol} {incr i} {
            lappend cells [_pad [lindex $headers $i] [lindex $w $i] [_alignAt $align $i]]
        }
        lappend out "| [join $cells { | }] |"
        set seps {}
        for {set i 0} {$i < $ncol} {incr i} {
            set dash [string repeat - [lindex $w $i]]
            switch -- [_alignAt $align $i] {
                r { set dash "[string range $dash 0 end-1]:" }
                c { set dash ":[string range $dash 1 end-1]:" }
                l { set dash ":[string range $dash 1 end]" }
            }
            lappend seps $dash
        }
        lappend out "| [join $seps { | }] |"
        foreach row $rows {
            set cells {}
            for {set i 0} {$i < $ncol} {incr i} {
                lappend cells [_pad [lindex $row $i] [lindex $w $i] [_alignAt $align $i]]
            }
            lappend out "| [join $cells { | }] |"
        }
    } else {
        set border "+"
        for {set i 0} {$i < $ncol} {incr i} {
            append border [string repeat - [expr {[lindex $w $i] + 2}]] "+"
        }
        lappend out $border
        set cells {}
        for {set i 0} {$i < $ncol} {incr i} {
            lappend cells [_pad [lindex $headers $i] [lindex $w $i] [_alignAt $align $i]]
        }
        lappend out "| [join $cells { | }] |"
        lappend out $border
        foreach row $rows {
            set cells {}
            for {set i 0} {$i < $ncol} {incr i} {
                lappend cells [_pad [lindex $row $i] [lindex $w $i] [_alignAt $align $i]]
            }
            lappend out "| [join $cells { | }] |"
        }
        lappend out $border
    }
    return [join $out "\n"]
}

package provide tclutils::tutable 0.2
