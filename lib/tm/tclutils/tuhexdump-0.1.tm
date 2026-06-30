# tclutils::tuhexdump -- classic hex/ascii dump in pure Tcl
# Description: classic hex/ascii dump in pure Tcl
# Category: Encoding · binary/checksums
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tubin 0.2

namespace eval ::tclutils {}
namespace eval ::tclutils::tuhexdump {
    namespace export data file
    variable version 0.1
}

proc ::tclutils::tuhexdump::ParseOptions {args} {
    set opts [dict create -width 16 -offset 0 -length -1]
    foreach {k v} $args {
        if {![dict exists $opts $k]} { error "unknown option $k" }
        dict set opts $k $v
    }
    return $opts
}

proc ::tclutils::tuhexdump::Printable {byte} {
    if {$byte >= 32 && $byte <= 126} {
        return [format %c $byte]
    }
    return "."
}

proc ::tclutils::tuhexdump::data {bytesData args} {
    set opts [ParseOptions {*}$args]
    set width [dict get $opts -width]
    set offset [dict get $opts -offset]
    set length [dict get $opts -length]

    if {$width <= 0} { error "-width must be greater than zero" }
    if {$offset < 0} { error "-offset must be zero or greater" }

    if {$length >= 0} {
        set bytesData [string range $bytesData $offset [expr {$offset + $length - 1}]]
    } else {
        set bytesData [string range $bytesData $offset end]
    }

    binary scan $bytesData cu* bytes
    set out {}
    set total [llength $bytes]
    for {set i 0} {$i < $total} {incr i $width} {
        set chunk [lrange $bytes $i [expr {$i + $width - 1}]]
        set chunkBytes [binary format cu* $chunk]
        set hexText [string tolower [::tclutils::tubin::bytesToHex $chunkBytes " "]]
        set ascii [::tclutils::tubin::ascii $chunkBytes]
        set padLen [expr {$width * 3 - 1}]
        append out [format "%08x  %-*s  |%s|\n" [expr {$offset + $i}] $padLen $hexText $ascii]
    }
    return [string trimright $out \n]
}

proc ::tclutils::tuhexdump::file {filename args} {
    set bytesData [::tclutils::common::readBinaryFile $filename]
    return [data $bytesData {*}$args]
}

package provide tclutils::tuhexdump 0.1
