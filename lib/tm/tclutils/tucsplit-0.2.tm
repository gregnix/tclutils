# tclutils::tucsplit -- split text files by content patterns
# Description: split text files by content patterns
# Category: Text · strings/coreutils
# Tcl 8.6+
#
# 0.2: every line keeps its line end, so the parts put together give the
# input again, as with csplit (0.1 dropped the LF at the end of each part).
# Parts are written in -encoding (default utf-8); file reads in the same
# encoding and keeps CRLF. A pattern is matched against the line without
# its line end.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucsplit {
    namespace export file splitText
    variable version 0.2
}

proc ::tclutils::tucsplit::_formatName {outdir prefix index digits suffix} {
    set number [format "%0${digits}d" $index]
    return [::file join $outdir ${prefix}${number}${suffix}]
}

proc ::tclutils::tucsplit::_prepareOutdir {outdir} {
    if {![::file exists $outdir]} { ::file mkdir $outdir }
    if {![::file isdirectory $outdir]} {
        return -code error -errorcode {TCLUTILS TUCSPLIT OUTDIR} "outdir is not a directory: $outdir"
    }
}

proc ::tclutils::tucsplit::_writePart {part outdir prefix index digits suffix enc} {
    set path [_formatName $outdir $prefix $index $digits $suffix]
    set fh [open $path wb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        puts -nonewline $fh [encoding convertto $enc [join $part ""]]
    } finally {
        close $fh
    }
    return $path
}

proc ::tclutils::tucsplit::_checkEncoding {enc} {
    if {$enc ni [encoding names]} {
        return -code error -level 2 -errorcode [list TCLUTILS TUCSPLIT ENCODING $enc] \
            "unknown encoding \"$enc\""
    }
}

proc ::tclutils::tucsplit::splitText {text pattern args} {
    set opts [::tclutils::common::parseOptions {-regexp 1 -keepmatch 1 -prefix xx -suffix {} -outdir . -digits 2 -empty 0 -encoding utf-8} {*}$args]
    set useRegexp [::tclutils::common::ensureBoolean [dict get $opts -regexp] -regexp]
    set keepmatch [::tclutils::common::ensureBoolean [dict get $opts -keepmatch] -keepmatch]
    set allowEmpty [::tclutils::common::ensureBoolean [dict get $opts -empty] -empty]
    set digits [::tclutils::common::ensurePositiveInteger [dict get $opts -digits] -digits]
    set outdir [dict get $opts -outdir]
    set prefix [dict get $opts -prefix]
    set suffix [dict get $opts -suffix]
    set enc [dict get $opts -encoding]
    _checkEncoding $enc
    _prepareOutdir $outdir

    set result {}
    set part {}
    set index 0
    # each line with its line end; matched without it
    foreach raw [regexp -all -inline {[^\n]*\n|[^\n]+$} $text] {
        set line [string trimright $raw "\n"]
        if {[string index $line end] eq "\r"} { set line [string range $line 0 end-1] }
        if {$useRegexp} {
            set matched [regexp -- $pattern $line]
        } else {
            set matched [string match $pattern $line]
        }
        if {$matched && ([llength $part] > 0 || $allowEmpty)} {
            lappend result [_writePart $part $outdir $prefix $index $digits $suffix $enc]
            incr index
            set part {}
        }
        if {!$matched || $keepmatch} {
            lappend part $raw
        }
    }
    if {[llength $part] > 0 || [llength $result] == 0 || $allowEmpty} {
        lappend result [_writePart $part $outdir $prefix $index $digits $suffix $enc]
    }
    return $result
}

proc ::tclutils::tucsplit::file {path pattern args} {
    set enc utf-8
    foreach {k v} $args { if {$k eq "-encoding"} { set enc $v } }
    _checkEncoding $enc
    # the bytes decoded as they are: CRLF stays
    set text [encoding convertfrom $enc [::tclutils::common::readBinaryFile $path]]
    tailcall splitText $text $pattern {*}$args
}

package provide tclutils::tucsplit 0.2
