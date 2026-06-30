# tclutils::tusplit -- split files into smaller parts
# Description: split files into smaller parts
# Category: Archive · filesystem
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tusplit {
    namespace export file lines bytes splitLines splitBytes
    variable version 0.1
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

proc ::tclutils::tusplit::splitLines {text args} {
    set opts [::tclutils::common::parseOptions {-lines 1000 -prefix x -suffix {} -outdir . -digits 2} {*}$args]
    set lineCount [::tclutils::common::ensurePositiveInteger [dict get $opts -lines] -lines]
    set digits [::tclutils::common::ensurePositiveInteger [dict get $opts -digits] -digits]
    set outdir [dict get $opts -outdir]
    _prepareOutdir $outdir

    set lines [::tclutils::common::splitLines $text]
    set result {}
    set part {}
    set index 0
    foreach line $lines {
        lappend part $line
        if {[llength $part] >= $lineCount} {
            set path [_formatName $outdir [dict get $opts -prefix] $index $digits [dict get $opts -suffix]]
            ::tclutils::common::writeFile $path [join $part \n]
            lappend result $path
            set part {}
            incr index
        }
    }
    if {[llength $part] > 0 || [llength $result] == 0} {
        set path [_formatName $outdir [dict get $opts -prefix] $index $digits [dict get $opts -suffix]]
        ::tclutils::common::writeFile $path [join $part \n]
        lappend result $path
    }
    return $result
}

proc ::tclutils::tusplit::splitBytes {data args} {
    set opts [::tclutils::common::parseOptions {-bytes 1024 -prefix x -suffix {} -outdir . -digits 2} {*}$args]
    set byteCount [::tclutils::common::ensurePositiveInteger [dict get $opts -bytes] -bytes]
    set digits [::tclutils::common::ensurePositiveInteger [dict get $opts -digits] -digits]
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
                if {$i >= [llength $args]} { error "missing value for option \"$opt\"" }
                incr modeCount
                set mode [string range $opt 1 end]
                set value [lindex $args $i]
            }
            default {
                lappend remaining $opt
                incr i
                if {$i >= [llength $args]} { error "missing value for option \"$opt\"" }
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
        set text [::tclutils::common::readFile $path]
        return [splitLines $text -lines $value {*}$remaining]
    }
}

proc ::tclutils::tusplit::lines {path n args} {
    tailcall file $path -lines $n {*}$args
}

proc ::tclutils::tusplit::bytes {path n args} {
    tailcall file $path -bytes $n {*}$args
}

package provide tclutils::tusplit 0.1
