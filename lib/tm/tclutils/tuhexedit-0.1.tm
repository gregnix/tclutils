# tclutils::tuhexedit -- small binary read/write/search/patch helpers
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tubin 0.1
package require tclutils::tuhexdump 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuhexedit {
    namespace export readBytes writeBytes findHex findString patch dump backup
    variable version 0.1
}

proc ::tclutils::tuhexedit::NormalizeOffset {offset} {
    if {[string match -nocase 0x* $offset]} {
        scan $offset %x n
        return $n
    }
    if {![string is integer -strict $offset] || $offset < 0} {
        return -code error -errorcode {TCLUTILS TUHEXEDIT OFFSET} "offset must be a non-negative integer"
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

proc ::tclutils::tuhexedit::writeBytes {filename offset bytes {createBackup 1}} {
    set offset [NormalizeOffset $offset]
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

proc ::tclutils::tuhexedit::findData {filename needle} {
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
    return [findData $filename $needle]
}

proc ::tclutils::tuhexedit::findString {filename text {encoding utf-8}} {
    set needle [encoding convertto $encoding $text]
    return [findData $filename $needle]
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

package provide tclutils::tuhexedit 0.1
