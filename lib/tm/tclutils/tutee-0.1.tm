# tclutils::tutee -- tee-like helpers
# Description: tee-like helpers
# Category: Text · strings/coreutils
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tutee {
    namespace export write writeFile copyChannel
    variable version 0.1
}

proc ::tclutils::tutee::_openOutputs {paths append} {
    set mode [expr {$append ? "a" : "w"}]
    set chans {}
    foreach path $paths {
        set fh [open $path $mode]
        fconfigure $fh -translation auto
        lappend chans $fh
    }
    return $chans
}

proc ::tclutils::tutee::_closeAll {chans} {
    set firstCode 0
    set firstResult ""
    set firstOpts {}
    foreach ch $chans {
        set code [catch {close $ch} result opts]
        if {$code != 0 && $firstCode == 0} {
            set firstCode $code
            set firstResult $result
            set firstOpts $opts
        }
    }
    if {$firstCode != 0} {
        return -options $firstOpts $firstResult
    }
    return
}

proc ::tclutils::tutee::write {data paths args} {
    set opts [::tclutils::common::parseOptions {-append 0 -stdout 0 -nonewline 0} {*}$args]
    set append [::tclutils::common::ensureBoolean [dict get $opts -append] -append]
    set stdout [::tclutils::common::ensureBoolean [dict get $opts -stdout] -stdout]
    set nonewline [::tclutils::common::ensureBoolean [dict get $opts -nonewline] -nonewline]

    set chans [::tclutils::tutee::_openOutputs $paths $append]
    try {
        foreach ch $chans {
            if {$nonewline} {
                puts -nonewline $ch $data
            } else {
                puts $ch $data
            }
        }
        if {$stdout} {
            if {$nonewline} { puts -nonewline stdout $data } else { puts stdout $data }
        }
    } finally {
        ::tclutils::tutee::_closeAll $chans
    }
    return $data
}

proc ::tclutils::tutee::writeFile {inputFile paths args} {
    set opts [::tclutils::common::parseOptions {-append 0 -stdout 0} {*}$args]
    set data [::tclutils::common::readFile $inputFile]
    return [write $data $paths -append [dict get $opts -append] -stdout [dict get $opts -stdout] -nonewline 1]
}

proc ::tclutils::tutee::copyChannel {inChan outChans args} {
    set opts [::tclutils::common::parseOptions {-stdout 0 -chunksize 8192} {*}$args]
    set stdout [::tclutils::common::ensureBoolean [dict get $opts -stdout] -stdout]
    set chunkSize [::tclutils::common::ensurePositiveInteger [dict get $opts -chunksize] -chunksize]
    set total 0
    while {![eof $inChan]} {
        set chunk [read $inChan $chunkSize]
        if {$chunk eq "" && [eof $inChan]} { break }
        incr total [string length $chunk]
        foreach ch $outChans { puts -nonewline $ch $chunk }
        if {$stdout} { puts -nonewline stdout $chunk }
    }
    return $total
}

package provide tclutils::tutee 0.1
