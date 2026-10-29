# tclutils::tudiff -- portable line based diff tools in pure Tcl
# Description: portable line based diff tools in pure Tcl
# Category: Text · strings/coreutils
# Tcl 8.6+
#
# Line ends (0.2): option -eol for text, files, unified, unifiedText,
# context, contextText:
#   ignore (default)  CRLF, CR and LF are the same, a missing newline at the
#                     end does not count (as up to 0.1)
#   strict            lines are compared with their line end: "a\r\n" and
#                     "a\n" differ, so does a missing final newline. In the
#                     ops of text/files a line keeps its end ("a\r\n");
#                     unified/context show the line without "\n" (a "\r"
#                     stays) and mark a missing final newline with
#                     "\ No newline at end of file", as GNU diff.
# files/unified/context also take -encoding ENC (default: system encoding).
# directory compares bytes (already in 0.1).
package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tudiff {
    namespace export text files unified unifiedText context contextText directory
    variable version 0.2
}

proc ::tclutils::tudiff::SplitLines {data} {
    return [::tclutils::common::splitLines $data]
}

# File text; -eol strict reads without line-end translation
proc ::tclutils::tudiff::ReadFile {filename {eol ignore} {enc ""}} {
    if {$eol eq "strict"} {
        set fh [open $filename r]
        try {
            fconfigure $fh -translation binary
            fconfigure $fh -encoding [expr {$enc eq "" ? [encoding system] : $enc}]
            return [read $fh]
        } finally {
            close $fh
        }
    }
    if {$enc ne ""} { return [::tclutils::common::readFile $filename -encoding $enc] }
    return [::tclutils::common::readFile $filename]
}

proc ::tclutils::tudiff::_eol {v} {
    if {$v ni {ignore strict}} {
        return -code error -errorcode {TCLUTILS TUDIFF OPTION EOL} \
            "-eol must be ignore or strict, got \"$v\""
    }
    return $v
}

# Lines of a text; strict: each line keeps its "\n" (and a "\r" before it)
proc ::tclutils::tudiff::_lines {text eol} {
    if {$eol ne "strict"} {
        regsub -all {\r\n?} $text "\n" text
        return [SplitLines $text]
    }
    if {$text eq ""} { return {} }
    return [regexp -all -inline {[^\n]*\n|[^\n]+$} $text]
}

proc ::tclutils::tudiff::_parseOptions {args} {
    return [::tclutils::common::parseOptions [dict create -maxcells 2000000 -eol ignore] {*}$args]
}

# One op line for unified/context output: without its "\n"; a line without
# one gets the GNU marker line
proc ::tclutils::tudiff::_show {prefix line} {
    if {[string index $line end] eq "\n"} {
        return [list "$prefix[string range $line 0 end-1]"]
    }
    return [list "$prefix$line" "\\ No newline at end of file"]
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
    set eol [_eol [dict get $opts -eol]]
    set a [_lines $oldText $eol]
    set b [_lines $newText $eol]
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
    set opts [::tclutils::common::parseOptions \
        [dict create -maxcells 2000000 -eol ignore -encoding ""] {*}$args]
    set eol [_eol [dict get $opts -eol]]
    set enc [dict get $opts -encoding]
    return [text [ReadFile $oldFile $eol $enc] [ReadFile $newFile $eol $enc] \
        -maxcells [dict get $opts -maxcells] -eol $eol]
}

proc ::tclutils::tudiff::unifiedText {oldText newText args} {
    set opts [::tclutils::common::parseOptions \
        [dict create -fromlabel old -tolabel new -context -1 -maxcells 2000000 -eol ignore] {*}$args]
    set eol [_eol [dict get $opts -eol]]
    set ops [text $oldText $newText -maxcells [dict get $opts -maxcells] -eol $eol]
    set oldCount [llength [_lines $oldText $eol]]
    set newCount [llength [_lines $newText $eol]]

    set out {}
    lappend out "--- [dict get $opts -fromlabel]"
    lappend out "+++ [dict get $opts -tolabel]"
    lappend out "@@ -1,$oldCount +1,$newCount @@"

    foreach op $ops {
        lassign $op kind line
        set p [dict get {equal " " delete - insert +} $kind]
        if {$eol eq "strict"} {
            lappend out {*}[_show $p $line]
        } else {
            lappend out "$p$line"
        }
    }
    return [join $out \n]
}

proc ::tclutils::tudiff::unified {oldFile newFile args} {
    set opts [::tclutils::common::parseOptions \
        [dict create -fromlabel $oldFile -tolabel $newFile -context -1 -maxcells 2000000 \
         -eol ignore -encoding ""] {*}$args]
    set eol [_eol [dict get $opts -eol]]
    set enc [dict get $opts -encoding]
    return [unifiedText [ReadFile $oldFile $eol $enc] [ReadFile $newFile $eol $enc] \
        {*}[dict remove $opts -encoding]]
}


proc ::tclutils::tudiff::contextText {oldText newText args} {
    set opts [::tclutils::common::parseOptions \
        [dict create -fromlabel old -tolabel new -context 3 -maxcells 2000000 -eol ignore] {*}$args]
    set eol [_eol [dict get $opts -eol]]
    set ops [text $oldText $newText -maxcells [dict get $opts -maxcells] -eol $eol]
    set out {}
    lappend out "*** [dict get $opts -fromlabel]"
    lappend out "--- [dict get $opts -tolabel]"
    lappend out "***************"
    foreach op $ops {
        lassign $op kind line
        set p [dict get {equal "  " delete "- " insert "+ "} $kind]
        if {$eol eq "strict"} {
            lappend out {*}[_show $p $line]
        } else {
            lappend out "$p$line"
        }
    }
    return [join $out \n]
}

proc ::tclutils::tudiff::context {oldFile newFile args} {
    set opts [::tclutils::common::parseOptions \
        [dict create -fromlabel $oldFile -tolabel $newFile -context 3 -maxcells 2000000 \
         -eol ignore -encoding ""] {*}$args]
    set eol [_eol [dict get $opts -eol]]
    set enc [dict get $opts -encoding]
    return [contextText [ReadFile $oldFile $eol $enc] [ReadFile $newFile $eol $enc] \
        {*}[dict remove $opts -encoding]]
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


package provide tclutils::tudiff 0.2
