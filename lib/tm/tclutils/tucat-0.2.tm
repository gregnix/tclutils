# tclutils::tucat -- small portable cat-like helpers
# Description: small portable cat-like helpers
# Category: Text · strings/coreutils
#
# 0.2: -number/-nonblank leave the end of the text after the last LF alone
# (0.1 numbered it as an empty line); files numbers the joined text in one
# run, as cat -n does (0.1 started at 1 for every file). Unknown options are
# an error.
package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucat {
    namespace export text file files
    variable version 0.2
}

proc ::tclutils::tucat::_opts {args} {
    set o [::tclutils::common::parseOptions {-number 0 -nonblank 0} {*}$args]
    dict set o -number [::tclutils::common::ensureBoolean [dict get $o -number] -number]
    dict set o -nonblank [::tclutils::common::ensureBoolean [dict get $o -nonblank] -nonblank]
    return $o
}

proc ::tclutils::tucat::text {text args} {
    set o [_opts {*}$args]
    set number [dict get $o -number]
    set nonblank [dict get $o -nonblank]
    if {!$number && !$nonblank} { return $text }
    # the empty rest after a final LF is not a line
    set tail ""
    if {[string index $text end] eq "\n"} {
        set text [string range $text 0 end-1]
        set tail "\n"
    }
    if {$text eq "" && $tail eq ""} { return "" }
    set out {}
    set n 1
    foreach line [split $text \n] {
        if {$nonblank ? $line ne "" : $number} {
            lappend out [format "%6d\t%s" $n $line]
            incr n
        } else {
            lappend out $line
        }
    }
    return "[join $out \n]$tail"
}

proc ::tclutils::tucat::file {path args} {
    set data [::tclutils::common::readFile $path]
    return [::tclutils::tucat::text $data {*}$args]
}

proc ::tclutils::tucat::files {paths args} {
    _opts {*}$args
    set data ""
    foreach path $paths {
        append data [::tclutils::common::readFile $path]
    }
    return [text $data {*}$args]
}

package provide tclutils::tucat 0.2
