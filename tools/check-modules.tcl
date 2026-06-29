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
# Usage:  tclsh tools/check-modules.tcl [repo-root] [-require test,doc,man,...] [-manifest tsv|md]
#   repo-root  : defaults to the parent of this script's directory
#   -require   : comma-separated subset of {test doc man bin demo umbr};
#                default "test,doc,man". These drive the REQUIRED gap list and
#                the exit code.
#   -manifest  : emit a machine-readable manifest instead of the human report.
#                Formats:
#                  tsv : tab-separated, one row per module
#                  md  : a Markdown table (header + separator + rows)
#                Columns: package version description test doc man repo path deps
#                "description" is read from a "# Description: ..." header line in
#                the module's .tm file (empty if absent). "deps" lists the
#                "package require" targets of the module (internal collection
#                modules and external packages alike), excluding Tcl/Tk and the
#                module itself. Flags are Y/N; version lists every version found
#                (comma-joined); path is relative to repo-root. Diagnostics go to
#                stderr so the manifest on stdout stays clean. The exit code is
#                unchanged, so "-manifest tsv >modules.tsv" still signals hygiene
#                problems.
#                Combine two repos (skip the second header -- tsv: 1 line,
#                md: 2 lines):
#                  check-modules.tcl <tclutils> -manifest tsv  >modules.tsv
#                  check-modules.tcl <tkutils>  -manifest tsv | tail -n +2 >>modules.tsv
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

# Read the "# Description: ..." header line from a .tm file (empty if absent).
proc moduleDesc {path} {
    if {[catch {readFile $path} data]} { return "" }
    foreach line [split $data \n] {
        if {[regexp -nocase {^\s*#\s*Description:\s*(.*)$} $line -> d]} {
            return [string trim $d]
        }
    }
    return ""
}

# Collect "package require" dependencies of a .tm file (unique, in order).
# Skips comment lines; handles "-exact"; drops Tcl, Tk and the module itself.
# Returns both internal (collection) and external package names.
proc moduleDeps {path selfPkg} {
    if {[catch {readFile $path} data]} { return {} }
    set deps {}
    foreach line [split $data \n] {
        if {[string match "#*" [string trimleft $line]]} continue
        foreach {_ pkg} [regexp -all -inline \
                {package require\s+(?:-exact\s+)?([A-Za-z][\w:]*)} $line] {
            if {$pkg in {Tcl Tk}} continue
            if {$pkg eq $selfPkg} continue
            if {$pkg ni $deps} { lappend deps $pkg }
        }
    }
    return $deps
}

proc main {argv} {
    set root ""
    set required {test doc man}
    set manifest ""
    for {set i 0} {$i < [llength $argv]} {incr i} {
        set a [lindex $argv $i]
        switch -glob -- $a {
            -require { set required [split [lindex $argv [incr i]] ", "] }
            -manifest - --manifest { set manifest [lindex $argv [incr i]] }
            -h - -help { puts "usage: check-modules.tcl \[repo-root\] \[-require test,doc,man,bin,demo,umbr\] \[-manifest tsv|md\]"; exit 0 }
            -* { puts stderr "unknown option: $a"; exit 2 }
            default { set root [file normalize $a] }
        }
    }
    set valid {test doc man bin demo umbr}
    set req {}
    foreach k $required { if {$k in $valid && $k ni $req} { lappend req $k } }
    set required $req

    if {$manifest ne "" && $manifest ni {tsv md}} {
        puts stderr "error: unknown -manifest format \"$manifest\" (supported: tsv, md)"; exit 2
    }
    set manifestMode [expr {$manifest ne ""}]

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
            puts stderr "?? cannot parse module file name: $base"
        }
    }

    set names [lsort -dictionary [dict keys $mods]]
    set dups {}
    set reqMissing [dict create]
    array set lacks {bin {} demo {} umbr {}}
    array set total {test 0 doc 0 man 0 bin 0 demo 0 umbr 0}

    if {$manifestMode} {
        set manifestCols {package version description test doc man repo path deps}
        if {$manifest eq "md"} {
            puts "| [join $manifestCols { | }] |"
            puts "|[string repeat {---|} [llength $manifestCols]]"
        } else {
            puts [join $manifestCols \t]
        }
    } else {
        puts "Module hygiene check: $repo"
        puts "Root:     $root"
        if {[llength $umbrellas]} { puts "Umbrella: [file tail [lindex $umbrellas 0]] ([dict size $umbrellaSet] modules listed)" }
        if {$umbrellaNote ne ""} { puts $umbrellaNote }
        puts "Required: [join $required { }]"
        puts ""
        puts [format "%-20s %-10s %-4s %-4s %-4s %-4s %-4s %-4s" NAME VERSION TEST DOC MAN BIN DEMO UMBR]
        puts [string repeat - 60]
    }

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

        if {$manifestMode} {
            set full [file join $modDir $name-[lindex $vers end].tm]
            if {[string match "$root/*" $full]} {
                set path [string range $full [expr {[string length $root] + 1}] end]
            } else {
                set path $full
            }
            set desc [moduleDesc $full]
            regsub -all {\s+} $desc " " desc
            set desc [string trim $desc]
            set deps [join [moduleDeps $full ${repo}::$name] ,]
            set tY [expr {$chk(test)?"Y":"N"}]
            set dY [expr {$chk(doc)?"Y":"N"}]
            set mY [expr {$chk(man)?"Y":"N"}]
            if {$manifest eq "md"} {
                set mdDesc [string map {| \\|} $desc]
                puts "| `${repo}::$name` | [join $vers ,] | $mdDesc | $tY | $dY | $mY | $repo | `$path` | $deps |"
            } else {
                puts [join [list ${repo}::$name [join $vers ,] $desc $tY $dY $mY $repo $path $deps] \t]
            }
        } else {
            set verCol [join $vers ,]; if {$isDup} { append verCol " !" }
            puts [format "%-20s %-10s %-4s %-4s %-4s %-4s %-4s %-4s" $name $verCol \
                [expr {$chk(test)?$y:$n}] [expr {$chk(doc)?$y:$n}] [expr {$chk(man)?$y:$n}] \
                [expr {$chk(bin)?$y:$n}]  [expr {$chk(demo)?$y:$n}] [expr {$chk(umbr)?$y:$n}]]
        }
    }

    set nMod [llength $names]

    if {!$manifestMode} {
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
    }
    exit [expr {([llength $dups] > 0 || [dict size $reqMissing] > 0) ? 1 : 0}]
}

main $argv
