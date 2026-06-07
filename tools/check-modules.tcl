#!/usr/bin/env tclsh
# ============================================================
# check-modules.tcl -- module hygiene check for tclutils / tkutils
#
# For every module  lib/tm/<repo>/<mod>-X.Y.tm  it reports a matrix:
#   VER  : exists in more than one version?  (must be unique)
#   TEST : tests/<mod>.test
#   DOC  : docs/<mod>.md
#   MAN  : man/mann/<mod>.n   OR  man/man1/<mod>.1
#   BIN  : bin/<mod>.tcl
#   DEMO : examples/demo-<mod>.tcl
#   UMBR : listed in the umbrella  (package require <repo>::<mod>)
#
# The "missing" report is split so it stays meaningful:
#   - REQUIRED gaps  -> things a well-formed module should have (actionable)
#   - other gaps     -> bin / demo / umbrella absences (often intentional:
#                       pure-lib modules have no CLI/GUI; optional modules are
#                       deliberately kept out of the umbrella)
#
# Usage:  tclsh tools/check-modules.tcl [repo-root] [-require test,doc,man,...]
#   repo-root : defaults to the parent of this script's directory
#   -require  : comma-separated subset of {test doc man bin demo umbr};
#               default "test,doc,man". These drive the REQUIRED gap list and
#               the exit code.
#
# Exit code: 1 if any module has multiple versions OR lacks a REQUIRED
#            artifact; otherwise 0.
# ============================================================

package require Tcl 8.6-

proc readFile {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set data [read $fh]
    close $fh
    return $data
}

proc main {argv} {
    set root ""
    set required {test doc man}
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set a [lindex $argv $i]
        switch -glob -- $a {
            -require { set required [split [lindex $argv [incr i]] ", "] }
            -h - -help { puts "usage: check-modules.tcl \[repo-root\] \[-require test,doc,man,bin,demo,umbr\]"; exit 0 }
            -* { puts stderr "unknown option: $a"; exit 2 }
            default { set root [file normalize $a] }
        }
    }
    set valid {test doc man bin demo umbr}
    set req {}
    foreach k $required { if {$k in $valid && $k ni $req} { lappend req $k } }
    set required $req

    if {$root eq ""} { set root [file dirname [file dirname [file normalize [info script]]]] }
    set repo [file tail $root]

    set modDir [file join $root lib tm $repo]
    if {![file isdirectory $modDir]} {
        set subs [glob -nocomplain -types d [file join $root lib tm *]]
        if {[llength $subs] == 1} { set modDir [lindex $subs 0]; set repo [file tail $modDir] }
    }
    if {![file isdirectory $modDir]} {
        puts stderr "error: module dir not found: [file join $root lib tm $repo]"; exit 2
    }

    set umbrellas [lsort [glob -nocomplain [file join $root lib tm ${repo}-*.tm]]]
    set umbrellaSet [dict create]
    set umbrellaNote ""
    if {[llength $umbrellas] == 0} {
        set umbrellaNote "WARNING: no umbrella ${repo}-*.tm found in lib/tm"
    } else {
        if {[llength $umbrellas] > 1} {
            set umbrellaNote "WARNING: multiple umbrella files: [join [lmap u $umbrellas {file tail $u}] {, }]"
        }
        foreach line [split [readFile [lindex $umbrellas 0]] \n] {
            if {[regexp "^\\s*package require ${repo}::(\\w+)" $line -> m]} { dict set umbrellaSet $m 1 }
        }
    }

    set mods [dict create]
    foreach f [lsort [glob -nocomplain [file join $modDir *.tm]]] {
        set base [file tail $f]
        if {[regexp {^(.+)-([0-9]+\.[0-9]+(?:\.[0-9]+)?)\.tm$} $base -> name ver]} {
            dict lappend mods $name $ver
        } else {
            puts "?? cannot parse module file name: $base"
        }
    }

    set names [lsort -dictionary [dict keys $mods]]
    set dups {}
    set reqMissing [dict create]
    array set lacks {bin {} demo {} umbr {}}
    array set total {test 0 doc 0 man 0 bin 0 demo 0 umbr 0}

    puts "Module hygiene check: $repo"
    puts "Root:     $root"
    if {[llength $umbrellas]} { puts "Umbrella: [file tail [lindex $umbrellas 0]] ([dict size $umbrellaSet] modules listed)" }
    if {$umbrellaNote ne ""} { puts $umbrellaNote }
    puts "Required: [join $required { }]"
    puts ""
    puts [format "%-20s %-10s %-4s %-4s %-4s %-4s %-4s %-4s" NAME VERSION TEST DOC MAN BIN DEMO UMBR]
    puts [string repeat - 60]

    set y "Y " ; set n ". "
    foreach name $names {
        set vers [lsort -dictionary [dict get $mods $name]]
        set isDup [expr {[llength $vers] > 1}]
        if {$isDup} { lappend dups [list $name $vers] }

        set chk(test) [file exists [file join $root tests    $name.test]]
        set chk(doc)  [file exists [file join $root docs     $name.md]]
        set chk(man)  [expr {[file exists [file join $root man mann $name.n]]
                          || [file exists [file join $root man man1 $name.1]]}]
        set chk(bin)  [file exists [file join $root bin      $name.tcl]]
        set chk(demo) [file exists [file join $root examples demo-$name.tcl]]
        set chk(umbr) [dict exists $umbrellaSet $name]

        foreach k {test doc man bin demo umbr} { if {$chk($k)} { incr total($k) } }
        set rmiss {}
        foreach k $required { if {!$chk($k)} { lappend rmiss $k } }
        if {[llength $rmiss]} { dict set reqMissing $name $rmiss }
        foreach k {bin demo umbr} {
            if {$k ni $required && !$chk($k)} { lappend lacks($k) $name }
        }

        set verCol [join $vers ,]; if {$isDup} { append verCol " !" }
        puts [format "%-20s %-10s %-4s %-4s %-4s %-4s %-4s %-4s" $name $verCol \
            [expr {$chk(test)?$y:$n}] [expr {$chk(doc)?$y:$n}] [expr {$chk(man)?$y:$n}] \
            [expr {$chk(bin)?$y:$n}]  [expr {$chk(demo)?$y:$n}] [expr {$chk(umbr)?$y:$n}]]
    }

    set nMod [llength $names]
    puts [string repeat - 60]
    puts [format "%-20s %-10s %-4d %-4d %-4d %-4d %-4d %-4d" "TOTAL ($nMod)" "" \
        $total(test) $total(doc) $total(man) $total(bin) $total(demo) $total(umbr)]

    puts "\n== Duplicate-version modules (must be unique) =="
    if {[llength $dups] == 0} { puts "  (none)" } else {
        foreach d $dups { puts "  [lindex $d 0]: [join [lindex $d 1] {, }]" }
    }

    puts "\n== Missing REQUIRED artifacts ([join $required {/}]) =="
    if {[dict size $reqMissing] == 0} { puts "  (none)" } else {
        foreach name $names {
            if {[dict exists $reqMissing $name]} { puts "  $name: [join [dict get $reqMissing $name] { }]" }
        }
    }

    puts "\n== Other gaps (often intentional; not in required set) =="
    set shown 0
    foreach {k label} {bin "no bin (no CLI launcher)" demo "no demo" umbr "not in umbrella"} {
        if {$k in $required} continue
        if {[llength $lacks($k)] == 0} continue
        set shown 1
        puts "  $label ([llength $lacks($k)]): [join $lacks($k) { }]"
    }
    if {!$shown} { puts "  (none)" }

    puts "\nSummary: $nMod modules; [llength $dups] multi-version; [dict size $reqMissing] missing a required artifact."
    exit [expr {([llength $dups] > 0 || [dict size $reqMissing] > 0) ? 1 : 0}]
}

main $argv
