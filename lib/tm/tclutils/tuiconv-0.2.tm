# tclutils::tuiconv -- small encoding conversion helpers in pure Tcl
# Description: small encoding conversion helpers in pure Tcl
# Category: Encoding · binary/checksums
# Tcl 8.6+
#
# 0.2: strict by default, the same under Tcl 8.6 and 9. A character the
# target encoding cannot hold is the error {TCLUTILS TUICONV UNMAPPABLE enc}
# (8.6 wrote "?" without a word, 9.0 raised a plain Tcl error); bytes that
# are not valid in the source encoding are {TCLUTILS TUICONV INVALID enc}.
# -replace 1 substitutes instead ("?" when encoding, U+FFFD or the byte's
# Latin-1 character when decoding, as the Tcl version does it).

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuiconv {
    namespace export encodings convert readFile writeFile convertFile
    variable version 0.2
    # Tcl 9 has encoding profiles; 8.6 converts leniently
    variable profiles [expr {![catch {encoding convertto -profile strict utf-8 a}]}]
}

proc ::tclutils::tuiconv::encodings {} {
    return [lsort [encoding names]]
}

proc ::tclutils::tuiconv::_checkEncoding {enc} {
    if {[lsearch -exact [encoding names] $enc] < 0} {
        return -code error -errorcode [list TCLUTILS TUICONV ENCODING $enc] "unknown encoding \"$enc\""
    }
    return $enc
}

proc ::tclutils::tuiconv::_replace {args} {
    set o [::tclutils::common::parseOptions {-replace 0} {*}$args]
    return [::tclutils::common::ensureBoolean [dict get $o -replace] -replace]
}

# Index of the first character where A and B differ.
proc ::tclutils::tuiconv::_firstDiff {a b} {
    set n [expr {min([string length $a], [string length $b])}]
    for {set i 0} {$i < $n} {incr i} {
        if {[string index $a $i] ne [string index $b $i]} { return $i }
    }
    return $n
}

# Text -> bytes in ENC.
proc ::tclutils::tuiconv::_encode {text enc replace} {
    variable profiles
    if {$profiles} {
        if {$replace} { return [encoding convertto -profile replace $enc $text] }
        if {![catch {encoding convertto -profile strict $enc $text} bytes]} {
            return $bytes
        }
        set i 0
        regexp {index (\d+)} $bytes -> i
    } else {
        set bytes [encoding convertto $enc $text]
        if {$replace || [encoding convertfrom $enc $bytes] eq $text} {
            return $bytes
        }
        set i [_firstDiff [encoding convertfrom $enc $bytes] $text]
    }
    set ch [string index $text $i]
    return -code error -errorcode [list TCLUTILS TUICONV UNMAPPABLE $enc] \
        "character [format U+%04X [scan $ch %c]] at index $i cannot be written in $enc"
}

# Bytes in ENC -> text.
proc ::tclutils::tuiconv::_decode {bytes enc replace} {
    variable profiles
    if {$profiles} {
        if {$replace} { return [encoding convertfrom -profile replace $enc $bytes] }
        if {![catch {encoding convertfrom -profile strict $enc $bytes} text]} {
            return $text
        }
        set i 0
        regexp {index (\d+)} $text -> i
    } else {
        set text [encoding convertfrom $enc $bytes]
        if {$replace || [encoding convertto $enc $text] eq $bytes} {
            return $text
        }
        set i [_firstDiff [encoding convertto $enc $text] $bytes]
    }
    return -code error -errorcode [list TCLUTILS TUICONV INVALID $enc] \
        "bytes at offset $i are not valid $enc"
}

proc ::tclutils::tuiconv::convert {data from to args} {
    set replace [_replace {*}$args]
    _checkEncoding $from
    _checkEncoding $to
    return [_encode [_decode $data $from $replace] $to $replace]
}

proc ::tclutils::tuiconv::readFile {filename encodingName args} {
    set replace [_replace {*}$args]
    _checkEncoding $encodingName
    set fh [open $filename rb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        set bytes [read $fh]
    } finally {
        close $fh
    }
    return [_decode $bytes $encodingName $replace]
}

proc ::tclutils::tuiconv::writeFile {filename text encodingName args} {
    set replace [_replace {*}$args]
    _checkEncoding $encodingName
    # converted before the file is opened: on an error the file stays as it was
    set bytes [_encode $text $encodingName $replace]
    set fh [open $filename wb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        puts -nonewline $fh $bytes
    } finally {
        close $fh
    }
    return $filename
}

proc ::tclutils::tuiconv::convertFile {infile outfile from to args} {
    set text [readFile $infile $from {*}$args]
    writeFile $outfile $text $to {*}$args
    return $outfile
}

package provide tclutils::tuiconv 0.2
