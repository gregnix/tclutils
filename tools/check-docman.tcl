#!/usr/bin/env tclsh
# ============================================================
# check-docman.tcl -- doc <-> man coverage / drift (tclutils / tkutils)
#
# For each module it reads the PUBLIC proc names from the source
# (lib/tm/<repo>/<mod>-*.tm: namespace export + proc ::<repo>::<mod>::name,
# excluding _private) and checks whether each is mentioned in
#   docs/<mod>.md        and
#   man/mann/<mod>.n  (or man/man1/<mod>.1)
#
# A name counts as "mentioned" only in a command context -- qualified
# (mod::name / ::repo::mod::name), in a `backtick` span, or roff \fB/\fI --
# so prose words like "join" or "clean" do NOT cause false hits.
#
# Reports per module: doc coverage, man coverage, names missing from each,
# plus presence (doc-only/man-only files) and mtime hint.
#
# No external dependencies. Repo-agnostic (parent of tools/).
# Usage:  tclsh tools/check-docman.tcl [repo-root]
# Exit 1 if anything is missing/one-sided, else 0.
# ============================================================
package require Tcl 8.6-

proc readFile {p} { set f [open $p r]; fconfigure $f -encoding utf-8; set d [read $f]; close $f; return $d }

proc publicNames {src repo mod} {
    regsub -all {\\\n} $src " " src   ;# join backslash continuations
    set d [dict create]
    foreach {full toks} [regexp -all -inline -line -- {namespace export +(.*)$} $src] {
        foreach t $toks {
            if {[regexp {^[A-Za-z][\w-]*$} $t] && ![string match _* $t]} { dict set d $t 1 }
        }
    }
    foreach {full nm} [regexp -all -inline -- "proc +::${repo}::${mod}::(\\w+)" $src] {
        if {![string match _* $nm]} { dict set d $nm 1 }
    }
    return [lsort [dict keys $d]]
}

proc mentioned {text repo mod name} {
    set q "(?:::)?(?:${repo}::)?${mod}::"
    set re "(?:${q}|`|\\\\fB|\\\\fI)${name}\\M"
    return [regexp -- $re $text]
}

proc main {argv} {
    set root [expr {[llength $argv] ? [file normalize [lindex $argv 0]] \
        : [file dirname [file dirname [file normalize [info script]]]]}]
    set repo [file tail $root]
    set docsDir [file join $root docs]
    set mannDir [file join $root man mann]
    set man1Dir [file join $root man man1]
    set tmDir   [file join $root lib tm $repo]

    set names [dict create]
    foreach f [glob -nocomplain [file join $docsDir *.md]] { dict set names [file rootname [file tail $f]] 1 }
    foreach f [glob -nocomplain [file join $mannDir *.n]]  { dict set names [file rootname [file tail $f]] 1 }
    foreach f [glob -nocomplain [file join $man1Dir *.1]]  { dict set names [file rootname [file tail $f]] 1 }
    set names [lsort -dictionary [dict keys $names]]

    puts "doc <-> man coverage: $repo   (root: $root)"
    puts [format "%-20s %-9s %-6s %-6s %s" NAME PRESENCE DOC MAN "MISSING"]
    puts [string repeat - 78]

    set nDoc 0; set nMan 0; set nOneSided 0; set nNoSrc 0
    foreach mod $names {
        set md [file join $docsDir $mod.md]
        set n  [file join $mannDir $mod.n]
        if {![file exists $n]} { set n [file join $man1Dir $mod.1] }
        set hasDoc [file exists $md]; set hasMan [file exists $n]
        if {$hasDoc && !$hasMan} { incr nOneSided; puts [format "%-20s %-9s %-6s %-6s %s" $mod doc-only - - "(man fehlt)"]; continue }
        if {!$hasDoc && $hasMan} { incr nOneSided; puts [format "%-20s %-9s %-6s %-6s %s" $mod man-only - - "(doc fehlt)"]; continue }

        set tm [lindex [lsort [glob -nocomplain [file join $tmDir $mod-*.tm]]] end]
        if {$tm eq ""} { incr nNoSrc; puts [format "%-20s %-9s %-6s %-6s %s" $mod both ? ? "(keine Quelle - uebersprungen)"]; continue }
        set exports [publicNames [readFile $tm] $repo $mod]
        if {[llength $exports] == 0} { puts [format "%-20s %-9s %-6s %-6s %s" $mod both - - "(keine Exports)"]; continue }
        set docTxt [readFile $md]; set manTxt [readFile $n]
        set missDoc {}; set missMan {}
        foreach e $exports {
            if {![mentioned $docTxt $repo $mod $e]} { lappend missDoc $e }
            if {![mentioned $manTxt $repo $mod $e]} { lappend missMan $e }
        }
        set N [llength $exports]
        set dc [expr {$N - [llength $missDoc]}]; set mc [expr {$N - [llength $missMan]}]
        if {[llength $missDoc]} { incr nDoc }
        if {[llength $missMan]} { incr nMan }
        set msg ""
        if {[llength $missDoc]} { append msg "doc-missing: [join $missDoc {, }]  " }
        if {[llength $missMan]} { append msg "man-missing: [join $missMan {, }]" }
        if {$msg eq ""} { set msg "ok" }
        puts [format "%-20s %-9s %-6s %-6s %s" $mod both $dc/$N $mc/$N $msg]
    }
    puts [string repeat - 78]
    puts "modules: [llength $names]; one-sided files: $nOneSided; no-source: $nNoSrc"
    puts "incomplete docs: $nDoc; incomplete man: $nMan"
    exit [expr {($nDoc||$nMan||$nOneSided)?1:0}]
}
main $argv
