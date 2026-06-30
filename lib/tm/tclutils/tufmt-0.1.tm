# tclutils::tufmt -- reflow text paragraphs to a target width (like fmt(1)).
# Description: reflow text paragraphs to a target width (like fmt(1)).
# Category: Text · strings/coreutils
# Paragraphs are separated by blank lines; within a paragraph, whitespace is
# collapsed and words are greedily wrapped. Each paragraph keeps the leading
# indentation of its first line. Tcl 8.6+ and 9.x.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tufmt {
    namespace export reflow reflowFile
    variable version 0.1
}

# Reflow $text. Option: -width n (default 75). Returns the reflowed text with
# paragraphs separated by a single blank line.
proc ::tclutils::tufmt::reflow {text args} {
    set opts [::tclutils::common::parseOptions {-width 75} {*}$args]
    set width [::tclutils::common::ensurePositiveInteger \
        [dict get $opts -width] -width]

    # group lines into paragraphs separated by blank (whitespace-only) lines
    set paras {}
    set cur {}
    foreach ln [split [string map {\r ""} $text] \n] {
        if {[string trim $ln] eq ""} {
            if {[llength $cur]} { lappend paras $cur; set cur {} }
        } else {
            lappend cur $ln
        }
    }
    if {[llength $cur]} { lappend paras $cur }

    set out {}
    foreach p $paras {
        regexp {^[ \t]*} [lindex $p 0] indent
        set words {}
        foreach ln $p {
            foreach w [regexp -all -inline {\S+} $ln] { lappend words $w }
        }
        set avail [expr {$width - [string length $indent]}]
        if {$avail < 1} { set avail 1 }
        set wrapped {}
        set line ""
        foreach w $words {
            if {$line eq ""} {
                set line $w
            } elseif {[string length "$line $w"] <= $avail} {
                append line " " $w
            } else {
                lappend wrapped $indent$line
                set line $w
            }
        }
        if {$line ne ""} { lappend wrapped $indent$line }
        lappend out [join $wrapped \n]
    }
    return [join $out "\n\n"]
}

# Reflow the contents of a file. Option: -width n (default 75).
proc ::tclutils::tufmt::reflowFile {path args} {
    return [reflow [::tclutils::common::readFile $path] {*}$args]
}

package provide tclutils::tufmt 0.1
