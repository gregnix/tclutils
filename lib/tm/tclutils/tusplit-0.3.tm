# tclutils::tusplit -- split files into smaller parts
# Description: split files into smaller parts
# Category: Archive · filesystem
# Tcl 8.6+
#
# 0.3: splitting by lines keeps every line end, so the parts put together
# give the input again (0.2 dropped the LF at the end of each part).
# file -lines works on the bytes (CRLF and the encoding stay); splitLines
# writes text in -encoding (default utf-8).

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tusplit {
    namespace export file lines bytes splitLines splitBytes
    variable version 0.3
}

proc ::tclutils::tusplit::_formatName {outdir prefix index digits suffix} {
    set number [format "%0${digits}d" $index]
    return [::file join $outdir ${prefix}${number}${suffix}]
}

proc ::tclutils::tusplit::_prepareOutdir {outdir} {
    if {![::file exists $outdir]} {
        ::file mkdir $outdir
    }
    if {![::file isdirectory $outdir]} {
        return -code error -errorcode {TCLUTILS TUSPLIT OUTDIR} "outdir is not a directory: $outdir"
    }
}

# Group DATA into chunks of N lines; each line keeps its LF, the last line
# may have none. Empty data gives no chunk.
proc ::tclutils::tusplit::_lineChunks {data n} {
    set chunks {}
    set cur ""
    set count 0
    foreach line [regexp -all -inline {[^\n]*\n|[^\n]+$} $data] {
        append cur $line
        if {[incr count] >= $n} {
            lappend chunks $cur
            set cur ""
            set count 0
        }
    }
    if {$cur ne ""} { lappend chunks $cur }
    return $chunks
}

# Write CHUNKS (byte strings) as numbered files; at least one file.
proc ::tclutils::tusplit::_writeChunks {chunks opts digits} {
    set outdir [dict get $opts -outdir]
    _prepareOutdir $outdir
    if {![llength $chunks]} { set chunks [list ""] }
    set result {}
    set index 0
    foreach chunk $chunks {
        set path [_formatName $outdir [dict get $opts -prefix] $index $digits [dict get $opts -suffix]]
        set fh [open $path wb]
        try {
            fconfigure $fh -translation binary -encoding iso8859-1
            puts -nonewline $fh $chunk
        } finally {
            close $fh
        }
        lappend result $path
        incr index
    }
    return $result
}

# Split TEXT into parts of -lines lines; each part is written in -encoding
# (default utf-8) with the line ends as they are in TEXT.
proc ::tclutils::tusplit::splitLines {text args} {
    set opts [::tclutils::common::parseOptions {-lines 1000 -prefix x -suffix {} -outdir . -digits 2 -encoding utf-8} {*}$args]
    set lineCount [::tclutils::common::ensurePositiveInteger [dict get $opts -lines] -lines]
    set digits [::tclutils::common::ensurePositiveInteger [dict get $opts -digits] -digits]
    set enc [dict get $opts -encoding]
    if {$enc ni [encoding names]} {
        return -code error -errorcode [list TCLUTILS TUSPLIT ENCODING $enc] \
            "unknown encoding \"$enc\""
    }
    set chunks [lmap c [_lineChunks $text $lineCount] {encoding convertto $enc $c}]
    return [_writeChunks $chunks $opts $digits]
}

# Split the bytes DATA at LF into parts of LINECOUNT lines.
proc ::tclutils::tusplit::_splitLineBytes {data lineCount args} {
    set opts [::tclutils::common::parseOptions {-prefix x -suffix {} -outdir . -digits 2} {*}$args]
    set digits [::tclutils::common::ensurePositiveInteger [dict get $opts -digits] -digits]
    return [_writeChunks [_lineChunks $data $lineCount] $opts $digits]
}

proc ::tclutils::tusplit::splitBytes {data args} {
    set opts [::tclutils::common::parseOptions {-bytes 1024 -prefix x -suffix {} -outdir . -digits 2} {*}$args]
    set byteCount [::tclutils::common::ensurePositiveInteger [dict get $opts -bytes] -bytes]
    set digits [::tclutils::common::ensurePositiveInteger [dict get $opts -digits] -digits]
    # DATA is a byte string: every character must be \x00..\xFF. Text is
    # converted first (encoding convertto utf-8). Checked before any file
    # is written, the same way under Tcl 8.6 and 9.
    if {[regexp {[^\x00-\xFF]} $data]} {
        return -code error -errorcode {TCLUTILS TUSPLIT BYTES} \
            "data contains characters above \\xFF; convert text first,\
            e.g. with \[encoding convertto utf-8 \$text\]"
    }
    set outdir [dict get $opts -outdir]
    _prepareOutdir $outdir

    set result {}
    set n [string length $data]
    set index 0
    for {set pos 0} {$pos < $n || ($n == 0 && $index == 0)} {incr pos $byteCount} {
        set chunk [string range $data $pos [expr {$pos + $byteCount - 1}]]
        set path [_formatName $outdir [dict get $opts -prefix] $index $digits [dict get $opts -suffix]]
        set fh [open $path wb]
        try {
            fconfigure $fh -translation binary -encoding iso8859-1
            puts -nonewline $fh $chunk
        } finally {
            close $fh
        }
        lappend result $path
        incr index
        if {$n == 0} { break }
    }
    return $result
}

# Same message and errorcode as tclutils::common::parseOptions.
proc ::tclutils::tusplit::_missingValue {opt} {
    return -code error -level 2 \
        -errorcode [list TCLUTILS COMMON OPTION $opt] \
        "missing value for option \"$opt\""
}

proc ::tclutils::tusplit::file {path args} {
    set modeCount 0
    set mode lines
    set value 1000
    set remaining {}
    set i 0
    while {$i < [llength $args]} {
        set opt [lindex $args $i]
        switch -- $opt {
            -lines - -bytes {
                incr i
                if {$i >= [llength $args]} { _missingValue $opt }
                incr modeCount
                set mode [string range $opt 1 end]
                set value [lindex $args $i]
            }
            default {
                lappend remaining $opt
                incr i
                if {$i >= [llength $args]} { _missingValue $opt }
                lappend remaining [lindex $args $i]
            }
        }
        incr i
    }
    if {$modeCount > 1} {
        return -code error -errorcode {TCLUTILS TUSPLIT MODE} "use only one of -lines or -bytes"
    }
    if {$mode eq "bytes"} {
        set data [::tclutils::common::readBinaryFile $path]
        return [splitBytes $data -bytes $value {*}$remaining]
    } else {
        # lines of the file as bytes: CRLF and the encoding stay as they are
        set lineCount [::tclutils::common::ensurePositiveInteger $value -lines]
        set data [::tclutils::common::readBinaryFile $path]
        return [_splitLineBytes $data $lineCount {*}$remaining]
    }
}

proc ::tclutils::tusplit::lines {path n args} {
    tailcall file $path -lines $n {*}$args
}

proc ::tclutils::tusplit::bytes {path n args} {
    tailcall file $path -bytes $n {*}$args
}

package provide tclutils::tusplit 0.3
