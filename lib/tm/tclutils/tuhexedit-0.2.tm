# tclutils::tuhexedit -- small binary read/write/search/patch helpers
# Description: small binary read/write/search/patch helpers
# Category: Encoding · binary/checksums
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tubin 0.2
package require tclutils::tuhexdump 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuhexedit {
    namespace export readBytes writeBytes findHex findString patch dump backup
    variable version 0.2
}

proc ::tclutils::tuhexedit::NormalizeOffset {offset} {
    if {[regexp -nocase {^0x([0-9a-f]+)$} $offset -> hex]} {
        return [expr {entier("0x$hex")}]
    }
    if {[string match -nocase 0x* $offset] || ![string is integer -strict $offset] || $offset < 0} {
        return -code error -errorcode {TCLUTILS TUHEXEDIT OFFSET} "offset must be a non-negative integer or 0x hex: $offset"
    }
    return $offset
}

proc ::tclutils::tuhexedit::readBytes {filename offset length} {
    set offset [NormalizeOffset $offset]
    if {![string is integer -strict $length] || $length < 0} {
        return -code error -errorcode {TCLUTILS TUHEXEDIT LENGTH} "length must be a non-negative integer"
    }
    set fh [open $filename rb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        seek $fh $offset start
        return [read $fh $length]
    } finally {
        close $fh
    }
}

# Overwrite bytes in place. The file keeps its length: writing past the end
# is an error (RANGE), so is a character above 255 in BYTES (BYTES). Both
# checks run before the backup is made, so a rejected call changes nothing.
proc ::tclutils::tuhexedit::writeBytes {filename offset bytes {createBackup 1}} {
    set offset [NormalizeOffset $offset]
    if {[regexp {[^\x00-\xff]} $bytes]} {
        return -code error -errorcode {TCLUTILS TUHEXEDIT BYTES} "data contains characters above 255; convert text with encoding convertto first"
    }
    set size [::file size $filename]
    set end [expr {$offset + [string length $bytes]}]
    if {$end > $size} {
        return -code error -errorcode {TCLUTILS TUHEXEDIT RANGE} "write of [string length $bytes] bytes at offset $offset passes the end of the file ($size bytes)"
    }
    if {$createBackup} { backup $filename }
    set fh [open $filename r+b]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        seek $fh $offset start
        puts -nonewline $fh $bytes
    } finally {
        close $fh
    }
    return $filename
}

proc ::tclutils::tuhexedit::backup {filename {backupName ""}} {
    if {$backupName eq ""} { set backupName "$filename.bak" }
    file copy -force $filename $backupName
    return $backupName
}

proc ::tclutils::tuhexedit::FindData {filename needle} {
    if {$needle eq ""} {
        return -code error -errorcode {TCLUTILS TUHEXEDIT NEEDLE} "needle must not be empty"
    }
    set data [::tclutils::common::readBinaryFile $filename]
    set out {}
    set start 0
    while 1 {
        set idx [string first $needle $data $start]
        if {$idx < 0} { break }
        lappend out $idx
        set start [expr {$idx + 1}]
    }
    return $out
}

proc ::tclutils::tuhexedit::findHex {filename hex} {
    set needle [::tclutils::tubin::hexToBytes $hex]
    return [FindData $filename $needle]
}

# A character the encoding cannot represent is an error (ENCODING) on both
# Tcl 8.6 (which would substitute "?") and Tcl 9 (strict profile). An unknown
# encoding name keeps Tcl's own {TCL LOOKUP ENCODING name}.
proc ::tclutils::tuhexedit::findString {filename text {encoding utf-8}} {
    if {[catch {encoding convertto $encoding $text} needle opts]} {
        if {[string match {TCL LOOKUP ENCODING*} [dict get $opts -errorcode]]} {
            return -options $opts $needle
        }
        set needle ""
        set bad 1
    } else {
        set bad [expr {[encoding convertfrom $encoding $needle] ne $text}]
    }
    if {$bad} {
        return -code error -errorcode {TCLUTILS TUHEXEDIT ENCODING} "text cannot be encoded in $encoding: $text"
    }
    return [FindData $filename $needle]
}

proc ::tclutils::tuhexedit::patch {filename offset hex args} {
    set opts [dict create -backup 1]
    set opts [::tclutils::common::parseOptions $opts {*}$args]
    set bytes [::tclutils::tubin::hexToBytes $hex]
    return [writeBytes $filename $offset $bytes [dict get $opts -backup]]
}

proc ::tclutils::tuhexedit::dump {filename args} {
    return [::tclutils::tuhexdump::file $filename {*}$args]
}

package provide tclutils::tuhexedit 0.2
