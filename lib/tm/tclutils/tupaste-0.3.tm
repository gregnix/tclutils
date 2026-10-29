# tclutils::tupaste -- paste-like helpers for combining line streams
# Description: paste-like helpers for combining line streams
# Category: Text · strings/coreutils
#
# Line ends: text/file output ends with LF exactly when the input does
# ("Jörg\n" stays "Jörg\n", "Jörg" stays "Jörg"), like tuhead, tutail, tunl,
# tutac and tused. Versions before 0.3 dropped the final LF.
package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tupaste { namespace export lines texts files }

proc ::tclutils::tupaste::_parseOptions {args} {
    return [::tclutils::common::parseOptions [dict create -delimiter "\t"] \
        {*}$args]
}

proc ::tclutils::tupaste::_textLines {text} {
    set lines [split $text \n]
    if {[llength $lines] > 0 && [lindex $lines end] eq ""} {
        set lines [lrange $lines 0 end-1]
    }
    return $lines
}

proc ::tclutils::tupaste::lines {lineLists args} {
    set opts [_parseOptions {*}$args]
    set delimiter [dict get $opts -delimiter]
    set max 0
    foreach ll $lineLists { if {[llength $ll] > $max} { set max [llength $ll] } }
    set out {}
    for {set row 0} {$row < $max} {incr row} {
        set cols {}
        foreach ll $lineLists { lappend cols [lindex $ll $row] }
        lappend out [join $cols $delimiter]
    }
    return [join $out \n]
}

proc ::tclutils::tupaste::texts {textList args} {
    set lineLists {}
    foreach t $textList { lappend lineLists [_textLines $t] }
    set out [lines $lineLists {*}$args]
    # LF at the end when one of the inputs ends with LF
    foreach t $textList {
        if {[string index $t end] eq "\n"} {
            return "$out\n"
        }
    }
    return $out
}

proc ::tclutils::tupaste::files {paths args} {
    set texts {}
    foreach path $paths {
        lappend texts [::tclutils::common::readFile $path]
    }
    return [texts $texts {*}$args]
}

package provide tclutils::tupaste 0.3
