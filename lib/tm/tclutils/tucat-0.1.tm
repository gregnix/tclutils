# tclutils::tucat -- small portable cat-like helpers
package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucat {
    namespace export text file files
}

proc ::tclutils::tucat::text {text args} {
    array set opts {-number 0 -nonblank 0}
    array set opts $args
    set out {}
    set n 1
    foreach line [split $text \n] {
        if {$opts(-number) || ($opts(-nonblank) && $line ne "")} {
            lappend out [format "%6d\t%s" $n $line]
            if {!$opts(-nonblank) || $line ne ""} {incr n}
        } else {
            lappend out $line
        }
    }
    return [join $out \n]
}

proc ::tclutils::tucat::file {path args} {
    set data [::tclutils::common::readFile $path]
    return [::tclutils::tucat::text $data {*}$args]
}

proc ::tclutils::tucat::files {paths args} {
    set parts {}
    foreach path $paths {
        lappend parts [::tclutils::tucat::file $path {*}$args]
    }
    return [join $parts ""]
}

package provide tclutils::tucat 0.1
