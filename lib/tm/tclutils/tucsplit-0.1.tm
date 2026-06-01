# tclutils::tucsplit -- split text files by content patterns
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucsplit {
    namespace export file splitText
    variable version 0.1
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

proc ::tclutils::tucsplit::_writePart {part outdir prefix index digits suffix} {
    set path [_formatName $outdir $prefix $index $digits $suffix]
    ::tclutils::common::writeFile $path [join $part \n]
    return $path
}

proc ::tclutils::tucsplit::splitText {text pattern args} {
    set opts [::tclutils::common::parseOptions {-regexp 1 -keepmatch 1 -prefix xx -suffix {} -outdir . -digits 2 -empty 0} {*}$args]
    set useRegexp [::tclutils::common::ensureBoolean [dict get $opts -regexp] -regexp]
    set keepmatch [::tclutils::common::ensureBoolean [dict get $opts -keepmatch] -keepmatch]
    set allowEmpty [::tclutils::common::ensureBoolean [dict get $opts -empty] -empty]
    set digits [::tclutils::common::ensurePositiveInteger [dict get $opts -digits] -digits]
    set outdir [dict get $opts -outdir]
    set prefix [dict get $opts -prefix]
    set suffix [dict get $opts -suffix]
    _prepareOutdir $outdir

    set result {}
    set part {}
    set index 0
    foreach line [::tclutils::common::splitLines $text] {
        if {$useRegexp} {
            set matched [regexp -- $pattern $line]
        } else {
            set matched [string match $pattern $line]
        }
        if {$matched && ([llength $part] > 0 || $allowEmpty)} {
            lappend result [_writePart $part $outdir $prefix $index $digits $suffix]
            incr index
            set part {}
        }
        if {!$matched || $keepmatch} {
            lappend part $line
        }
    }
    if {[llength $part] > 0 || [llength $result] == 0 || $allowEmpty} {
        lappend result [_writePart $part $outdir $prefix $index $digits $suffix]
    }
    return $result
}

proc ::tclutils::tucsplit::file {path pattern args} {
    set text [::tclutils::common::readFile $path]
    tailcall splitText $text $pattern {*}$args
}

package provide tclutils::tucsplit 0.1
