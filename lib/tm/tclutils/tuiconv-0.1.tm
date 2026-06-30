# tclutils::tuiconv -- small encoding conversion helpers in pure Tcl
# Description: small encoding conversion helpers in pure Tcl
# Category: Encoding · binary/checksums
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuiconv {
    namespace export encodings convert readFile writeFile convertFile
    variable version 0.1
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

proc ::tclutils::tuiconv::convert {data from to} {
    _checkEncoding $from
    _checkEncoding $to
    set unicode [encoding convertfrom $from $data]
    return [encoding convertto $to $unicode]
}

proc ::tclutils::tuiconv::readFile {filename encodingName} {
    _checkEncoding $encodingName
    set fh [open $filename rb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        set bytes [read $fh]
    } finally {
        close $fh
    }
    return [encoding convertfrom $encodingName $bytes]
}

proc ::tclutils::tuiconv::writeFile {filename text encodingName} {
    _checkEncoding $encodingName
    set bytes [encoding convertto $encodingName $text]
    set fh [open $filename wb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        puts -nonewline $fh $bytes
    } finally {
        close $fh
    }
    return $filename
}

proc ::tclutils::tuiconv::convertFile {infile outfile from to} {
    set text [readFile $infile $from]
    writeFile $outfile $text $to
    return $outfile
}

package provide tclutils::tuiconv 0.1
