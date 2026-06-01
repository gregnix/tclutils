# tclutils::turev -- rev-like reversal of characters within each line
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::turev {
    namespace export line text file
    variable version 0.1
}

# Reverse the characters of a single line.
proc ::tclutils::turev::line {str} {
    return [string reverse $str]
}

# Reverse the characters of every line. A trailing newline is preserved.
proc ::tclutils::turev::text {text} {
    set trailing 0
    set lines [split $text \n]
    if {$text ne "" && [string index $text end] eq "\n"} {
        set lines [lrange $lines 0 end-1]
        set trailing 1
    }
    set out {}
    foreach l $lines {
        lappend out [string reverse $l]
    }
    set result [join $out \n]
    if {$trailing} { append result \n }
    return $result
}

proc ::tclutils::turev::file {path} {
    return [text [::tclutils::common::readFile $path]]
}

package provide tclutils::turev 0.1
