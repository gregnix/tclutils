# tclutils::tucmp -- portable byte-wise file comparison in pure Tcl
# Description: portable byte-wise file comparison in pure Tcl
# Category: Archive · filesystem
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucmp {
    namespace export data files equal firstDifference
    variable version 0.2
}

# Compare two byte strings (every character 0..255). A character above 255
# is not a byte: the caller converts text with encoding convertto first.
proc ::tclutils::tucmp::data {a b} {
    foreach {s which} [list $a 1 $b 2] {
        if {[regexp {[^\x00-\xff]} $s]} {
            return -code error -errorcode {TCLUTILS TUCMP BYTES} "data$which contains characters above 255; convert text with encoding convertto first"
        }
    }
    set lenA [string length $a]
    set lenB [string length $b]
    set min [expr {$lenA < $lenB ? $lenA : $lenB}]

    if {$a eq $b} {
        return [dict create equal 1 offset -1 byte1 {} byte2 {} size1 $lenA size2 $lenB]
    }

    for {set i 0} {$i < $min} {incr i} {
        if {[string index $a $i] ne [string index $b $i]} {
            binary scan [string index $a $i] cu ba
            binary scan [string index $b $i] cu bb
            return [dict create equal 0 offset $i byte1 $ba byte2 $bb \
                size1 $lenA size2 $lenB]
        }
    }

    set byte1 {}
    set byte2 {}
    if {$lenA > $min} {
        binary scan [string index $a $min] cu byte1
    }
    if {$lenB > $min} {
        binary scan [string index $b $min] cu byte2
    }
    return [dict create equal 0 offset $min byte1 $byte1 byte2 $byte2 size1 $lenA size2 $lenB]
}

proc ::tclutils::tucmp::files {file1 file2} {
    return [data [::tclutils::common::readBinaryFile $file1] [::tclutils::common::readBinaryFile $file2]]
}

proc ::tclutils::tucmp::equal {file1 file2} {
    return [dict get [files $file1 $file2] equal]
}

proc ::tclutils::tucmp::firstDifference {file1 file2} {
    return [dict get [files $file1 $file2] offset]
}

package provide tclutils::tucmp 0.2
