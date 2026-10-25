# tclutils::tunl -- nl-like line numbering in pure Tcl
# Description: nl-like line numbering in pure Tcl
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tunl {
    namespace export text file
    variable version 0.2
}

proc ::tclutils::tunl::_options {args} {
    set defaults [dict create -start 1 -increment 1 -width 6 -separator "\t" -style nonempty]
    set opts [::tclutils::common::parseOptions $defaults {*}$args]
    set style [dict get $opts -style]
    if {$style ni {all nonempty none}} {
        return -code error -errorcode {TCLUTILS TUNL STYLE} \
            "invalid -style \"$style\": must be all, nonempty, or none"
    }
    foreach {opt reason} {-start START -increment INCREMENT} {
        set v [dict get $opts $opt]
        if {![string is entier -strict $v]} {
            return -code error -errorcode [list TCLUTILS TUNL $reason] \
                "invalid $opt \"$v\": must be an integer"
        }
        dict set opts $opt [expr {$v}]
    }
    set width [dict get $opts -width]
    if {![string is entier -strict $width] || $width < 1} {
        return -code error -errorcode {TCLUTILS TUNL WIDTH} \
            "invalid -width \"$width\": must be an integer >= 1"
    }
    return $opts
}

# Number the lines of a text. A trailing newline is preserved and does not
# create an extra numbered line.
proc ::tclutils::tunl::text {text args} {
    set opts [_options {*}$args]
    set n     [dict get $opts -start]
    set inc   [dict get $opts -increment]
    set width [dict get $opts -width]
    set sep   [dict get $opts -separator]
    set style [dict get $opts -style]

    set trailing 0
    set lines [split $text \n]
    if {$text ne "" && [string index $text end] eq "\n"} {
        set lines [lrange $lines 0 end-1]
        set trailing 1
    }

    set out {}
    foreach line $lines {
        switch -- $style {
            all      { set doNumber 1 }
            none     { set doNumber 0 }
            nonempty { set doNumber [expr {$line ne ""}] }
        }
        if {$doNumber} {
            lappend out [format "%*s%s%s" $width $n $sep $line]
            incr n $inc
        } else {
            lappend out [format "%*s%s%s" $width "" $sep $line]
        }
    }

    set result [join $out \n]
    if {$trailing} { append result \n }
    return $result
}

proc ::tclutils::tunl::file {path args} {
    return [text [::tclutils::common::readFile $path] {*}$args]
}

package provide tclutils::tunl 0.2
