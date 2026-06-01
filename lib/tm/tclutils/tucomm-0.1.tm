# tclutils::tucomm -- comm-like helpers for sorted line sets
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucomm {
    namespace export compareLines text files formatColumns
    variable version 0.1
}

proc ::tclutils::tucomm::_options {args} {
    set defaults [dict create -sort 0 -nocase 0]
    return [::tclutils::common::parseOptions $defaults {*}$args]
}

proc ::tclutils::tucomm::_key {line nocase} {
    if {$nocase} { return [string tolower $line] }
    return $line
}

proc ::tclutils::tucomm::compareLines {aLines bLines args} {
    set opts [_options {*}$args]
    set doSort [::tclutils::common::ensureBoolean [dict get $opts -sort] -sort]
    set nocase [::tclutils::common::ensureBoolean [dict get $opts -nocase] -nocase]

    if {$doSort} {
        if {$nocase} {
            set aLines [lsort -dictionary -nocase $aLines]
            set bLines [lsort -dictionary -nocase $bLines]
        } else {
            set aLines [lsort -dictionary $aLines]
            set bLines [lsort -dictionary $bLines]
        }
    }

    set onlyA {}
    set onlyB {}
    set both {}
    set ia 0
    set ib 0
    set na [llength $aLines]
    set nb [llength $bLines]

    while {$ia < $na || $ib < $nb} {
        if {$ia >= $na} {
            lappend onlyB [lindex $bLines $ib]
            incr ib
            continue
        }
        if {$ib >= $nb} {
            lappend onlyA [lindex $aLines $ia]
            incr ia
            continue
        }

        set av [lindex $aLines $ia]
        set bv [lindex $bLines $ib]
        set cmp [string compare [_key $av $nocase] [_key $bv $nocase]]
        if {$cmp == 0} {
            lappend both $av
            incr ia
            incr ib
        } elseif {$cmp < 0} {
            lappend onlyA $av
            incr ia
        } else {
            lappend onlyB $bv
            incr ib
        }
    }

    return [dict create onlyA $onlyA onlyB $onlyB both $both]
}

proc ::tclutils::tucomm::text {aText bText args} {
    set aLines [::tclutils::common::splitLines $aText]
    set bLines [::tclutils::common::splitLines $bText]
    return [compareLines $aLines $bLines {*}$args]
}

proc ::tclutils::tucomm::files {aFile bFile args} {
    set aText [::tclutils::common::readFile $aFile]
    set bText [::tclutils::common::readFile $bFile]
    return [text $aText $bText {*}$args]
}

proc ::tclutils::tucomm::formatColumns {comparison args} {
    set opts [::tclutils::common::parseOptions [dict create -separator \t] {*}$args]
    set sep [dict get $opts -separator]
    set out {}
    foreach line [dict get $comparison onlyA] { append out "$line\n" }
    foreach line [dict get $comparison onlyB] { append out "$sep$line\n" }
    foreach line [dict get $comparison both] { append out "$sep$sep$line\n" }
    return [string trimright $out \n]
}

package provide tclutils::tucomm 0.1
