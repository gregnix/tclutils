# tclutils::tuzip -- small ZIP/ODF helper in pure Tcl
# Tcl 8.6+
#
# Scope of 0.1:
#   names/extract/readMember/create ZIP files using stored or deflated entries.
#   Good enough for ODT/ODS/ODG inspection and small generated archives.

package require Tcl 8.6-
# Tcl 8.6 provides zlib as a package. Tcl 9 provides zlib as a core command
# and no longer provides a separate zlib package. Do not catch this: on Tcl 8.6
# a missing zlib package is a hard dependency error.
if {[package vcompare [info tclversion] 9.0] < 0} {
    package require zlib
}
package require tclutils::common 0.1
package require tclutils::tubin 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuzip {
    namespace export entries names readMember extract create createMembers
    variable version 0.1
}

proc ::tclutils::tuzip::U16 {v} { expr {$v & 0xffff} }
proc ::tclutils::tuzip::U32 {v} { expr {$v & 0xffffffff} }
proc ::tclutils::tuzip::Pack16 {v} { ::tclutils::tubin::packU16LE [U16 $v] }
proc ::tclutils::tuzip::Pack32 {v} { ::tclutils::tubin::packU32LE [U32 $v] }
proc ::tclutils::tuzip::Unpack16 {bytes} { ::tclutils::tubin::u16le $bytes }
proc ::tclutils::tuzip::Unpack32 {bytes} { ::tclutils::tubin::u32le $bytes }

proc ::tclutils::tuzip::DosTime {seconds} {
    # clock format may return zero-padded fields such as 08 or 09.
    # In Tcl expr, bare 08/09 are invalid octal numbers, so every
    # component is converted explicitly with scan before arithmetic.
    set parts [clock format $seconds -format {%Y %m %d %H %M %S}]
    lassign $parts y mo d h mi s
    foreach var {y mo d h mi s} {
        if {[scan [set $var] %d value] != 1} {
            return -code error -errorcode {TCLUTILS TUZIP TIME} \
                "invalid date/time component: [set $var]"
        }
        set $var $value
    }
    if {$y < 1980} { set y 1980; set mo 1; set d 1; set h 0; set mi 0; set s 0 }
    set time [expr {($h << 11) | ($mi << 5) | int($s / 2)}]
    set date [expr {(($y - 1980) << 9) | ($mo << 5) | $d}]
    return [::list $time $date]
}

proc ::tclutils::tuzip::FindEOCD {data} {
    set n [string length $data]
    set start [expr {$n - 22}]
    set min [expr {$n - 65557}]
    if {$min < 0} { set min 0 }
    for {set i $start} {$i >= $min} {incr i -1} {
        if {[string range $data $i [expr {$i + 3}]] eq "PK\x05\x06"} {
            return $i
        }
    }
    return -code error -errorcode {TCLUTILS TUZIP EOCD} "not a ZIP file: end of central directory not found"
}

proc ::tclutils::tuzip::CentralEntries {data} {
    set eocd [FindEOCD $data]
    if {[string length $data] < $eocd + 22} {
        return -code error -errorcode {TCLUTILS TUZIP EOCD SHORT} "truncated ZIP end record"
    }
    set diskEntries [Unpack16 [string range $data [expr {$eocd + 10}] [expr {$eocd + 11}]]]
    set cdSize [Unpack32 [string range $data [expr {$eocd + 12}] [expr {$eocd + 15}]]]
    set cdOffset [Unpack32 [string range $data [expr {$eocd + 16}] [expr {$eocd + 19}]]]

    set out {}
    set pos $cdOffset
    for {set idx 0} {$idx < $diskEntries} {incr idx} {
        if {[string range $data $pos [expr {$pos + 3}]] ne "PK\x01\x02"} {
            return -code error -errorcode {TCLUTILS TUZIP CENTRAL} "invalid central directory header at offset $pos"
        }
        if {[string length $data] < $pos + 46} {
            return -code error -errorcode {TCLUTILS TUZIP CENTRAL SHORT} "truncated central directory header"
        }
        set flags   [Unpack16 [string range $data [expr {$pos + 8}]  [expr {$pos + 9}]]]
        set method  [Unpack16 [string range $data [expr {$pos + 10}] [expr {$pos + 11}]]]
        set crc     [Unpack32 [string range $data [expr {$pos + 16}] [expr {$pos + 19}]]]
        set csize   [Unpack32 [string range $data [expr {$pos + 20}] [expr {$pos + 23}]]]
        set usize   [Unpack32 [string range $data [expr {$pos + 24}] [expr {$pos + 27}]]]
        set nlen    [Unpack16 [string range $data [expr {$pos + 28}] [expr {$pos + 29}]]]
        set xlen    [Unpack16 [string range $data [expr {$pos + 30}] [expr {$pos + 31}]]]
        set clen    [Unpack16 [string range $data [expr {$pos + 32}] [expr {$pos + 33}]]]
        set lhoff   [Unpack32 [string range $data [expr {$pos + 42}] [expr {$pos + 45}]]]
        set nameStart [expr {$pos + 46}]
        set nameEnd [expr {$nameStart + $nlen - 1}]
        set name [string range $data $nameStart $nameEnd]
        # ZIP names are byte strings; for common UTF-8 names Tcl will keep them usable.
        lappend out [dict create name $name method $method flags $flags crc $crc \
            compressedSize $csize uncompressedSize $usize localOffset $lhoff]
        set pos [expr {$pos + 46 + $nlen + $xlen + $clen}]
    }
    return $out
}

proc ::tclutils::tuzip::entries {zipfile} {
    set data [::tclutils::common::readBinaryFile $zipfile]
    return [CentralEntries $data]
}

proc ::tclutils::tuzip::names {zipfile} {
    set names {}
    foreach e [entries $zipfile] { lappend names [dict get $e name] }
    return $names
}

proc ::tclutils::tuzip::EntryData {zipData entry} {
    set off [dict get $entry localOffset]
    if {[string range $zipData $off [expr {$off + 3}]] ne "PK\x03\x04"} {
        return -code error -errorcode {TCLUTILS TUZIP LOCAL} "invalid local file header for [dict get $entry name]"
    }
    set nlen [Unpack16 [string range $zipData [expr {$off + 26}] [expr {$off + 27}]]]
    set xlen [Unpack16 [string range $zipData [expr {$off + 28}] [expr {$off + 29}]]]
    set start [expr {$off + 30 + $nlen + $xlen}]
    set end [expr {$start + [dict get $entry compressedSize] - 1}]
    set payload [string range $zipData $start $end]
    set method [dict get $entry method]
    switch -- $method {
        0 { set data $payload }
        8 { set data [zlib inflate $payload] }
        default {
            return -code error -errorcode [::list TCLUTILS TUZIP METHOD $method] \
                "unsupported ZIP compression method $method for [dict get $entry name]"
        }
    }
    set crc [U32 [zlib crc32 $data]]
    if {$crc != [dict get $entry crc]} {
        return -code error -errorcode {TCLUTILS TUZIP CRC} "CRC mismatch for [dict get $entry name]"
    }
    return $data
}

proc ::tclutils::tuzip::readMember {zipfile member} {
    set data [::tclutils::common::readBinaryFile $zipfile]
    foreach e [CentralEntries $data] {
        if {[dict get $e name] eq $member} {
            return [EntryData $data $e]
        }
    }
    return -code error -errorcode [::list TCLUTILS TUZIP MEMBER $member] "member not found: $member"
}

proc ::tclutils::tuzip::extract {zipfile member outfile} {
    set data [::tclutils::tuzip::readMember $zipfile $member]
    set dir [file dirname $outfile]
    if {$dir ne "." && ![file isdirectory $dir]} { file mkdir $dir }
    set fh [open $outfile wb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        puts -nonewline $fh $data
    } finally {
        close $fh
    }
    return $outfile
}

proc ::tclutils::tuzip::NormalizeName {name} {
    set name [string map {\\ /} $name]
    while {[string match "/*" $name]} { set name [string range $name 1 end] }
    return $name
}

proc ::tclutils::tuzip::RelativeName {base path} {
    set base [file normalize $base]
    set path [file normalize $path]
    set bparts [file split $base]
    set pparts [file split $path]
    set n [llength $bparts]
    if {[lrange $pparts 0 [expr {$n - 1}]] eq $bparts} {
        set rel [lrange $pparts $n end]
        if {[llength $rel] == 0} { return [file tail $path] }
        return [join $rel /]
    }
    return [file tail $path]
}

proc ::tclutils::tuzip::MakeLocalHeader {name method crc csize usize time date} {
    set out "PK\x03\x04"
    append out [Pack16 20] [Pack16 0] [Pack16 $method] [Pack16 $time] [Pack16 $date]
    append out [Pack32 $crc] [Pack32 $csize] [Pack32 $usize]
    append out [Pack16 [string length $name]] [Pack16 0] $name
    return $out
}

proc ::tclutils::tuzip::MakeCentralHeader {name method crc csize usize time date localOffset} {
    set out "PK\x01\x02"
    append out [Pack16 20] [Pack16 20] [Pack16 0] [Pack16 $method] [Pack16 $time] [Pack16 $date]
    append out [Pack32 $crc] [Pack32 $csize] [Pack32 $usize]
    append out [Pack16 [string length $name]] [Pack16 0] [Pack16 0]
    append out [Pack16 0] [Pack16 0] [Pack32 0] [Pack32 $localOffset] $name
    return $out
}

proc ::tclutils::tuzip::create {zipfile files args} {
    set opts [::tclutils::common::parseOptions [dict create -base "" -compress 1] {*}$args]
    set compress [::tclutils::common::ensureBoolean [dict get $opts -compress] -compress]
    set base [dict get $opts -base]

    set out ""
    set central ""
    set count 0
    foreach file $files {
        if {[file isdirectory $file]} { continue }
        if {$base ne ""} {
            set name [NormalizeName [RelativeName $base $file]]
        } else {
            set name [NormalizeName [file tail $file]]
        }
        set bytes [::tclutils::common::readBinaryFile $file]
        set crc [U32 [zlib crc32 $bytes]]
        set usize [string length $bytes]
        if {$compress} {
            set payload [zlib deflate $bytes]
            set method 8
        } else {
            set payload $bytes
            set method 0
        }
        set csize [string length $payload]
        lassign [DosTime [file mtime $file]] time date
        set localOffset [string length $out]
        append out [MakeLocalHeader $name $method $crc $csize $usize $time $date] $payload
        append central [MakeCentralHeader $name $method $crc $csize $usize $time $date $localOffset]
        incr count
    }
    set cdOffset [string length $out]
    set cdSize [string length $central]
    append out $central
    append out "PK\x05\x06" [Pack16 0] [Pack16 0] [Pack16 $count] [Pack16 $count] \
        [Pack32 $cdSize] [Pack32 $cdOffset] [Pack16 0]

    set fh [open $zipfile wb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        puts -nonewline $fh $out
    } finally {
        close $fh
    }
    return $zipfile
}

# --- ADD TO lib/tm/tclutils/tuzip-0.1.tm ---
# 1) namespace export: ... extract create  ->  ... extract create createMembers
# 2) Insert the following proc just before the final 'package provide':

# Create a ZIP from in-memory members with per-entry compression and explicit
# order. `members` is a list of dicts, each with keys: name (archive path,
# required), content (raw bytes, required), method (stored|deflate, default
# deflate). The member order is preserved -- e.g. an ODF container can put
# `mimetype` first as stored and compress the XML parts in a single call.
# Option -mtime EPOCH sets a fixed timestamp for all entries (default: now).
proc ::tclutils::tuzip::createMembers {zipfile members args} {
    set opts [::tclutils::common::parseOptions [dict create -mtime ""] {*}$args]
    set mtime [dict get $opts -mtime]
    if {$mtime eq ""} { set mtime [clock seconds] }
    lassign [DosTime $mtime] time date

    set out ""
    set central ""
    set count 0
    foreach m $members {
        if {![dict exists $m name] || ![dict exists $m content]} {
            return -code error -errorcode {TCLUTILS TUZIP MEMBER} \
                "member needs name and content"
        }
        set name [NormalizeName [dict get $m name]]
        set bytes [dict get $m content]
        set method [expr {[dict exists $m method] ? [dict get $m method] : "deflate"}]
        set crc [U32 [zlib crc32 $bytes]]
        set usize [string length $bytes]
        switch -- $method {
            stored  { set payload $bytes;                 set mcode 0 }
            deflate { set payload [zlib deflate $bytes];  set mcode 8 }
            default {
                return -code error -errorcode {TCLUTILS TUZIP METHOD} \
                    "unknown method \"$method\" (use stored or deflate)"
            }
        }
        set csize [string length $payload]
        set localOffset [string length $out]
        append out [MakeLocalHeader $name $mcode $crc $csize $usize $time $date] $payload
        append central [MakeCentralHeader $name $mcode $crc $csize $usize $time $date $localOffset]
        incr count
    }
    set cdOffset [string length $out]
    set cdSize [string length $central]
    append out $central
    append out "PK\x05\x06" [Pack16 0] [Pack16 0] [Pack16 $count] [Pack16 $count] \
        [Pack32 $cdSize] [Pack32 $cdOffset] [Pack16 0]

    set fh [open $zipfile wb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        puts -nonewline $fh $out
    } finally {
        close $fh
    }
    return $zipfile
}

package provide tclutils::tuzip 0.1
