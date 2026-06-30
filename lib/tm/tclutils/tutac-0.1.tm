# tclutils::tutac -- tac-like reversal of line order
# Description: tac-like reversal of line order
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tutac {
    namespace export text file lines
    variable version 0.1
}

# Reverse a list of lines.
proc ::tclutils::tutac::lines {lineList} {
    return [lreverse $lineList]
}

# Reverse the order of the lines in a text. A trailing newline is preserved
# (so "a\nb\n" becomes "b\na\n").
proc ::tclutils::tutac::text {text} {
    if {$text eq ""} { return "" }
    set trailing [expr {[string index $text end] eq "\n"}]
    set lst [split $text \n]
    if {$trailing} {
        set lst [lrange $lst 0 end-1]
    }
    set result [join [lreverse $lst] \n]
    if {$trailing} { append result \n }
    return $result
}

proc ::tclutils::tutac::file {path} {
    return [text [::tclutils::common::readFile $path]]
}

package provide tclutils::tutac 0.1
