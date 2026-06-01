# tclutils::tudiff -- portable line based diff tools in pure Tcl
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tudiff {
    namespace export text files unified unifiedText context contextText directory
    variable version 0.1.2
}

proc ::tclutils::tudiff::SplitLines {data} {
    return [::tclutils::common::splitLines $data]
}

proc ::tclutils::tudiff::ReadFile {filename} {
    return [::tclutils::common::readFile $filename]
}

proc ::tclutils::tudiff::_parseOptions {args} {
    return [::tclutils::common::parseOptions [dict create -maxcells 2000000] {*}$args]
}

proc ::tclutils::tudiff::_checkMaxCells {n m maxcells} {
    if {![string is integer -strict $maxcells] || $maxcells < 1} {
        return -code error -errorcode {TCLUTILS TUDIFF OPTION MAXCELLS} \
            "-maxcells must be a positive integer"
    }
    if {[expr {$n * $m}] > $maxcells} {
        return -code error -errorcode {TCLUTILS TUDIFF TOO_LARGE} \
            "diff input too large for LCS table: $n x $m cells exceeds -maxcells $maxcells"
    }
}

proc ::tclutils::tudiff::text {oldText newText args} {
    set opts [_parseOptions {*}$args]
    set a [SplitLines $oldText]
    set b [SplitLines $newText]
    set n [llength $a]
    set m [llength $b]

    if {$oldText eq $newText} {
        set ops {}
        foreach line $a { lappend ops [list equal $line] }
        return $ops
    }

    _checkMaxCells $n $m [dict get $opts -maxcells]

    # Dynamic-programming LCS table.  This is intentionally simple and robust
    # for small to medium reference files.  The -maxcells guard prevents
    # accidental O(n*m) blow-ups on very large files.
    array set lcs {}
    for {set i 0} {$i <= $n} {incr i} { set lcs($i,$m) 0 }
    for {set j 0} {$j <= $m} {incr j} { set lcs($n,$j) 0 }

    for {set i [expr {$n - 1}]} {$i >= 0} {incr i -1} {
        set ai [lindex $a $i]
        for {set j [expr {$m - 1}]} {$j >= 0} {incr j -1} {
            if {$ai eq [lindex $b $j]} {
                set lcs($i,$j) [expr {$lcs([expr {$i + 1}],[expr {$j + 1}]) + 1}]
            } elseif {$lcs([expr {$i + 1}],$j) >= $lcs($i,[expr {$j + 1}])} {
                set lcs($i,$j) $lcs([expr {$i + 1}],$j)
            } else {
                set lcs($i,$j) $lcs($i,[expr {$j + 1}])
            }
        }
    }

    set ops {}
    set i 0
    set j 0
    while {$i < $n && $j < $m} {
        set ai [lindex $a $i]
        set bj [lindex $b $j]
        if {$ai eq $bj} {
            lappend ops [list equal $ai]
            incr i
            incr j
        } elseif {$lcs([expr {$i + 1}],$j) >= $lcs($i,[expr {$j + 1}])} {
            lappend ops [list delete $ai]
            incr i
        } else {
            lappend ops [list insert $bj]
            incr j
        }
    }
    while {$i < $n} {
        lappend ops [list delete [lindex $a $i]]
        incr i
    }
    while {$j < $m} {
        lappend ops [list insert [lindex $b $j]]
        incr j
    }
    return $ops
}

proc ::tclutils::tudiff::files {oldFile newFile args} {
    return [text [ReadFile $oldFile] [ReadFile $newFile] {*}$args]
}

proc ::tclutils::tudiff::unifiedText {oldText newText args} {
    set opts [::tclutils::common::parseOptions \
        [dict create -fromlabel old -tolabel new -context -1 -maxcells 2000000] {*}$args]

    set ops [text $oldText $newText -maxcells [dict get $opts -maxcells]]
    set oldCount [llength [SplitLines $oldText]]
    set newCount [llength [SplitLines $newText]]

    set out {}
    lappend out "--- [dict get $opts -fromlabel]"
    lappend out "+++ [dict get $opts -tolabel]"
    lappend out "@@ -1,$oldCount +1,$newCount @@"

    foreach op $ops {
        lassign $op kind line
        switch -- $kind {
            equal  { lappend out " $line" }
            delete { lappend out "-$line" }
            insert { lappend out "+$line" }
        }
    }
    return [join $out \n]
}

proc ::tclutils::tudiff::unified {oldFile newFile args} {
    set opts [::tclutils::common::parseOptions \
        [dict create -fromlabel $oldFile -tolabel $newFile -context -1 -maxcells 2000000] {*}$args]
    return [unifiedText [ReadFile $oldFile] [ReadFile $newFile] {*}$opts]
}


proc ::tclutils::tudiff::contextText {oldText newText args} {
    set opts [::tclutils::common::parseOptions \
        [dict create -fromlabel old -tolabel new -context 3 -maxcells 2000000] {*}$args]
    set ops [text $oldText $newText -maxcells [dict get $opts -maxcells]]
    set out {}
    lappend out "*** [dict get $opts -fromlabel]"
    lappend out "--- [dict get $opts -tolabel]"
    lappend out "***************"
    foreach op $ops {
        lassign $op kind line
        switch -- $kind {
            equal  { lappend out "  $line" }
            delete { lappend out "- $line" }
            insert { lappend out "+ $line" }
        }
    }
    return [join $out \n]
}

proc ::tclutils::tudiff::context {oldFile newFile args} {
    set opts [::tclutils::common::parseOptions \
        [dict create -fromlabel $oldFile -tolabel $newFile -context 3 -maxcells 2000000] {*}$args]
    return [contextText [ReadFile $oldFile] [ReadFile $newFile] {*}$opts]
}

proc ::tclutils::tudiff::_relativeFiles {root recursive} {
    set result {}
    set root [file normalize $root]
    set prefixLen [string length $root]
    proc ::tclutils::tudiff::_walkDir {base prefixLen recursive resultVar} {
        upvar 1 $resultVar result
        foreach item [lsort [glob -nocomplain -directory $base *]] {
            if {[file isdirectory $item]} {
                if {$recursive} {
                    _walkDir $item $prefixLen $recursive result
                }
            } elseif {[file isfile $item]} {
                set rel [string range [file normalize $item] [expr {$prefixLen + 1}] end]
                lappend result [file split $rel]
            }
        }
    }
    _walkDir $root $prefixLen $recursive result
    set normalized {}
    foreach parts $result { lappend normalized [file join {*}$parts] }
    return [lsort -unique $normalized]
}

proc ::tclutils::tudiff::directory {oldDir newDir args} {
    set opts [::tclutils::common::parseOptions [dict create -recursive 1] {*}$args]
    set recursive [::tclutils::common::ensureBoolean [dict get $opts -recursive] -recursive]
    set oldFiles [_relativeFiles $oldDir $recursive]
    set newFiles [_relativeFiles $newDir $recursive]

    set oldSet [dict create]
    set newSet [dict create]
    foreach f $oldFiles { dict set oldSet $f 1 }
    foreach f $newFiles { dict set newSet $f 1 }
    set all [lsort -unique [concat $oldFiles $newFiles]]

    set out {}
    foreach rel $all {
        set inOld [dict exists $oldSet $rel]
        set inNew [dict exists $newSet $rel]
        if {$inOld && !$inNew} {
            lappend out [list only-old $rel]
        } elseif {!$inOld && $inNew} {
            lappend out [list only-new $rel]
        } else {
            set a [::tclutils::common::readBinaryFile [file join $oldDir $rel]]
            set b [::tclutils::common::readBinaryFile [file join $newDir $rel]]
            if {$a eq $b} {
                lappend out [list equal $rel]
            } else {
                lappend out [list different $rel]
            }
        }
    }
    return $out
}


package provide tclutils::tudiff 0.1
