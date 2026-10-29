# tclutils::tupatch -- patch-like applier for unified diffs
# Description: patch-like applier for unified diffs
# Category: Text · strings/coreutils
# Tcl 8.6+
#
# Applies a unified diff (as produced by tclutils::tudiff, and also general
# multi-hunk "diff -u" / "git diff" output) to a source text or file.
# Pure Tcl, no external dependencies.
#
# 0.3: the line end at the end of the text is kept. A source that ends with
# LF gives a result that ends with LF; "\ No newline at end of file" in the
# patch removes or adds it as diff -u means it (0.2 always dropped it).

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tupatch {
    namespace export text fromFile parse
    variable version 0.3
}

# Parse a single "@@ -a,b +c,d @@" hunk header.
# Returns a dict {oldStart oldLen newStart newLen} or "" if the line is not a
# hunk header. Missing lengths default to 1 (unified-diff convention).
proc ::tclutils::tupatch::_parseHunkHeader {line} {
    if {[regexp {^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@} \
            $line -> oldStart oldLen newStart newLen]} {
        if {$oldLen eq ""} { set oldLen 1 }
        if {$newLen eq ""} { set newLen 1 }
        return [dict create \
            oldStart $oldStart oldLen $oldLen newStart $newStart newLen $newLen]
    }
    return ""
}

# Verify that the source line at $pos equals $expected; otherwise the patch
# does not apply. $nearLine is the 1-based hunk start for the message.
proc ::tclutils::tupatch::_expect {srcVar pos expected nearLine} {
    upvar 1 $srcVar src
    if {$pos >= [llength $src]} {
        return -code error -errorcode {TCLUTILS TUPATCH CONTEXT} \
            "patch does not apply: source ends before hunk near line $nearLine"
    }
    set actual [lindex $src $pos]
    if {$actual ne $expected} {
        return -code error -errorcode {TCLUTILS TUPATCH CONTEXT} \
            "patch does not apply: expected \"$expected\" but found\
             \"$actual\" at source line [expr {$pos + 1}]"
    }
}

# Parse a unified-diff text into a list of hunk dicts.
# Each hunk dict has: oldStart oldLen newStart newLen body oldNoNl newNoNl
# where body is a list of {kind content} pairs, kind in {" " "+" "-"};
# oldNoNl/newNoNl are 1 when "\ No newline at end of file" follows the last
# old/new line of the hunk.
# Preamble and "---"/"+++"/"diff"/"index" header lines are skipped.
proc ::tclutils::tupatch::parse {patchText} {
    set lines [split $patchText \n]
    set n [llength $lines]
    set hunks {}
    set i 0
    while {$i < $n} {
        set hdr [_parseHunkHeader [lindex $lines $i]]
        if {$hdr eq ""} {
            incr i
            continue
        }
        incr i
        set body {}
        set oldNoNl 0
        set newNoNl 0
        while {$i < $n} {
            set bl [lindex $lines $i]
            if {[_parseHunkHeader $bl] ne ""} {
                break
            }
            set c [string index $bl 0]
            if {$c eq " " || $c eq "+" || $c eq "-"} {
                lappend body [list $c [string range $bl 1 end]]
                incr i
            } elseif {$c eq "\\"} {
                # "\ No newline at end of file": applies to the line before
                switch -- [lindex $body end 0] {
                    "-" { set oldNoNl 1 }
                    "+" { set newNoNl 1 }
                    " " { set oldNoNl 1; set newNoNl 1 }
                }
                incr i
            } else {
                # Blank separator or trailing prose -- end of this hunk.
                break
            }
        }
        lappend hunks [dict merge $hdr [dict create body $body \
            oldNoNl $oldNoNl newNoNl $newNoNl]]
    }
    return $hunks
}

# Apply a unified diff to a source text and return the patched text.
# Options:
#   -reverse 0|1   apply the patch in reverse (undo). Default 0.
#   -strict  0|1   verify context/delete lines against the source and error on
#                  mismatch. Default 1.
proc ::tclutils::tupatch::text {sourceText patchText args} {
    set opts [::tclutils::common::parseOptions \
        [dict create -reverse 0 -strict 1] {*}$args]
    set reverse [::tclutils::common::ensureBoolean [dict get $opts -reverse] -reverse]
    set strict  [::tclutils::common::ensureBoolean [dict get $opts -strict] -strict]

    set src [::tclutils::common::splitLines $sourceText]
    set srcNl [expr {[string index $sourceText end] eq "\n"}]
    set hunks [parse $patchText]
    if {[llength $hunks] == 0} {
        return $sourceText
    }

    set out {}
    set srcPos 0
    # the line end at the end: as in the source, unless a marker says otherwise
    set nl $srcNl
    foreach h $hunks {
        if {$reverse} {
            set toNoNl [dict get $h oldNoNl]
            set fromNoNl [dict get $h newNoNl]
        } else {
            set toNoNl [dict get $h newNoNl]
            set fromNoNl [dict get $h oldNoNl]
        }
        if {$toNoNl} {
            set nl 0
        } elseif {$fromNoNl} {
            set nl 1
        }
        if {$reverse} {
            set oldStart [dict get $h newStart]
        } else {
            set oldStart [dict get $h oldStart]
        }
        set target [expr {$oldStart - 1}]
        if {$target < $srcPos} {
            return -code error -errorcode {TCLUTILS TUPATCH RANGE} \
                "hunk at source line $oldStart overlaps an earlier hunk"
        }
        while {$srcPos < $target} {
            if {$srcPos >= [llength $src]} {
                return -code error -errorcode {TCLUTILS TUPATCH RANGE} \
                    "hunk start beyond end of source at line $oldStart"
            }
            lappend out [lindex $src $srcPos]
            incr srcPos
        }
        foreach entry [dict get $h body] {
            lassign $entry kind content
            if {$reverse} {
                if {$kind eq "+"} {
                    set kind "-"
                } elseif {$kind eq "-"} {
                    set kind "+"
                }
            }
            switch -- $kind {
                " " {
                    if {$strict} { _expect src $srcPos $content $oldStart }
                    lappend out [lindex $src $srcPos]
                    incr srcPos
                }
                "-" {
                    if {$strict} { _expect src $srcPos $content $oldStart }
                    incr srcPos
                }
                "+" {
                    lappend out $content
                }
            }
        }
    }
    while {$srcPos < [llength $src]} {
        lappend out [lindex $src $srcPos]
        incr srcPos
    }
    if {$nl && [llength $out]} { return "[join $out \n]\n" }
    return [join $out \n]
}

# Read $sourceFile, apply $patchText, and return the patched text.
proc ::tclutils::tupatch::fromFile {sourceFile patchText args} {
    return [text [::tclutils::common::readFile $sourceFile] $patchText {*}$args]
}

package provide tclutils::tupatch 0.3
