# tclutils::tummdb -- a pure-Tcl reader for the MaxMind DB (.mmdb) binary
# Description: a pure-Tcl reader for the MaxMind DB (.mmdb) binary format, version 2.0 of the spec.
# Category: Network · web
# format, version 2.0 of the spec. Supports IPv4 and IPv6 lookups against
# GeoLite2 / GeoIP2 / DB-IP style databases.
#
# Binary access goes through the tclutils::tubin reader cursor; the data
# decoder uses a single cursor and resolves pointers by seek/restore.
#
# Public API:
#   ::tclutils::tummdb::open path      -> handle
#   ::tclutils::tummdb::metadata h     -> dict
#   ::tclutils::tummdb::lookup h ip    -> decoded record (dict/list) or ""
#   ::tclutils::tummdb::close h
#
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::tubin 0.3-

namespace eval ::tclutils {}
namespace eval ::tclutils::tummdb {
    namespace export metadata lookup
    variable version 0.1
    variable db          ;# array: per-handle state
    variable counter 0
}

# --- open / metadata / close -------------------------------------------------

proc ::tclutils::tummdb::open {path} {
    variable db
    variable counter
    set h "tummdb[incr counter]"

    set fp [::open $path rb]
    set raw [read $fp]
    ::close $fp

    set marker "\xab\xcd\xefMaxMind.com"
    set mpos [string last $marker $raw]
    if {$mpos < 0} {
        return -code error -errorcode {TCLUTILS TUMMDB FORMAT} \
            "not a MaxMind DB file: $path"
    }
    set metaStart [expr {$mpos + [string length $marker]}]

    set rd [::tclutils::tubin::reader new $raw $metaStart]
    set meta [DecodeValue $rd $metaStart]
    $rd destroy
    if {![dict exists $meta node_count] || ![dict exists $meta record_size]} {
        return -code error -errorcode {TCLUTILS TUMMDB FORMAT} \
            "invalid MMDB metadata in $path"
    }

    set recordSize [dict get $meta record_size]
    set nodeCount  [dict get $meta node_count]
    set nodeBytes  [expr {$recordSize * 2 / 8}]
    set treeSize   [expr {$nodeBytes * $nodeCount}]

    set db($h,raw)        $raw
    set db($h,meta)       $meta
    set db($h,recordSize) $recordSize
    set db($h,nodeCount)  $nodeCount
    set db($h,nodeBytes)  $nodeBytes
    set db($h,ipVersion)  [dict get $meta ip_version]
    set db($h,dataStart)  [expr {$treeSize + 16}]
    return $h
}

proc ::tclutils::tummdb::metadata {h} {
    variable db
    if {![info exists db($h,meta)]} {
        return -code error -errorcode {TCLUTILS TUMMDB HANDLE} "unknown handle: $h"
    }
    return $db($h,meta)
}

proc ::tclutils::tummdb::close {h} {
    variable db
    array unset db $h,*
    return
}

# --- search tree -------------------------------------------------------------

proc ::tclutils::tummdb::Record {h node which} {
    variable db
    set raw  $db($h,raw)
    set base [expr {$node * $db($h,nodeBytes)}]
    switch -- $db($h,recordSize) {
        24 {
            return [::tclutils::tubin::uintbe $raw [expr {$base + ($which ? 3 : 0)}] 3]
        }
        28 {
            set mid [::tclutils::tubin::u8 $raw [expr {$base + 3}]]
            if {$which == 0} {
                set high [expr {($mid & 0xf0) >> 4}]
                return [expr {($high << 24) | [::tclutils::tubin::uintbe $raw $base 3]}]
            }
            set high [expr {$mid & 0x0f}]
            return [expr {($high << 24) | [::tclutils::tubin::uintbe $raw [expr {$base + 4}] 3]}]
        }
        32 {
            return [::tclutils::tubin::uintbe $raw [expr {$base + ($which ? 4 : 0)}] 4]
        }
        default {
            return -code error -errorcode {TCLUTILS TUMMDB RECORDSIZE} \
                "unsupported record_size: $db($h,recordSize)"
        }
    }
}

proc ::tclutils::tummdb::IpBits {h ip} {
    variable db
    if {[string first : $ip] >= 0} {
        set bits {}
        foreach w [ExpandV6 $ip] {
            for {set i 15} {$i >= 0} {incr i -1} {
                lappend bits [expr {($w >> $i) & 1}]
            }
        }
        return $bits
    }
    lassign [split $ip .] a b c d
    set v [expr {wide($a)*16777216 + $b*65536 + $c*256 + $d}]
    set bits {}
    for {set i 31} {$i >= 0} {incr i -1} {
        lappend bits [expr {($v >> $i) & 1}]
    }
    if {$db($h,ipVersion) == 6} {
        set zeros {}
        for {set i 0} {$i < 96} {incr i} { lappend zeros 0 }
        set bits [concat $zeros $bits]
    }
    return $bits
}

proc ::tclutils::tummdb::ExpandV6 {ip} {
    if {[string first :: $ip] >= 0} {
        lassign [split $ip ::] head tail
        set hp [expr {$head eq "" ? {} : [split $head :]}]
        set tp [expr {$tail eq "" ? {} : [split $tail :]}]
        set miss [expr {8 - [llength $hp] - [llength $tp]}]
        set words $hp
        for {set i 0} {$i < $miss} {incr i} { lappend words 0 }
        set words [concat $words $tp]
    } else {
        set words [split $ip :]
    }
    set out {}
    foreach w $words {
        if {$w eq ""} { set w 0 }
        lappend out [expr {"0x$w"}]
    }
    return $out
}

proc ::tclutils::tummdb::lookup {h ip} {
    variable db
    if {![info exists db($h,raw)]} {
        return -code error -errorcode {TCLUTILS TUMMDB HANDLE} "unknown handle: $h"
    }
    set nodeCount $db($h,nodeCount)
    set node 0
    foreach bit [IpBits $h $ip] {
        if {$node >= $nodeCount} break
        set node [Record $h $node $bit]
    }
    if {$node <= $nodeCount} {
        return ""    ;# no data for this IP
    }
    set offset [expr {($node - $nodeCount - 16) + $db($h,dataStart)}]
    set rd [::tclutils::tubin::reader new $db($h,raw) $offset]
    set value [DecodeValue $rd $db($h,dataStart)]
    $rd destroy
    return $value
}

# --- data section decoder ----------------------------------------------------
# Decode one field at the cursor's current position. $base is the section start
# used to resolve pointers (data section, or metadata section). Pointers seek
# the cursor to the target, decode, then restore the position after the field.
proc ::tclutils::tummdb::DecodeValue {rd base} {
    set ctrl [$rd u8]
    set type [expr {$ctrl >> 5}]
    if {$type == 0} {
        set type [expr {[$rd u8] + 7}]
    }

    if {$type == 1} {
        set psize [expr {($ctrl >> 3) & 0x3}]
        set v3    [expr {$ctrl & 0x7}]
        switch -- $psize {
            0 { set ptr [expr {($v3 << 8)  | [$rd u8]}] }
            1 { set ptr [expr {(($v3 << 16) | [$rd uintbe 2]) + 2048}] }
            2 { set ptr [expr {(($v3 << 24) | [$rd uintbe 3]) + 526336}] }
            3 { set ptr [$rd uintbe 4] }
        }
        set ret [$rd tell]
        $rd seek [expr {$base + $ptr}]
        set value [DecodeValue $rd $base]
        $rd seek $ret
        return $value
    }

    set size [expr {$ctrl & 0x1f}]
    if {$size >= 29} {
        if {$size == 29} {
            set size [expr {29 + [$rd u8]}]
        } elseif {$size == 30} {
            set size [expr {285 + [$rd uintbe 2]}]
        } else {
            set size [expr {65821 + [$rd uintbe 3]}]
        }
    }

    switch -- $type {
        2  { return [encoding convertfrom utf-8 [$rd bytes $size]] }
        3  { return [$rd f64be] }
        4  { return [$rd bytes $size] }
        5 - 6 - 9 - 10 { return [$rd uintbe $size] }
        8  {
            set v [$rd uintbe $size]
            if {$size == 4 && $v >= 0x80000000} { set v [expr {$v - 0x100000000}] }
            return $v
        }
        7  {
            set d [dict create]
            for {set i 0} {$i < $size} {incr i} {
                set key [DecodeValue $rd $base]
                dict set d $key [DecodeValue $rd $base]
            }
            return $d
        }
        11 {
            set a {}
            for {set i 0} {$i < $size} {incr i} {
                lappend a [DecodeValue $rd $base]
            }
            return $a
        }
        14 { return $size }
        15 { return [$rd f32be] }
        default {
            return -code error -errorcode {TCLUTILS TUMMDB TYPE} \
                "unsupported MMDB data type: $type"
        }
    }
}

package provide tclutils::tummdb 0.1
