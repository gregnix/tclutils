package require Tcl 8.6-
# Run every *.test in this directory. Set TCLUTILS_TM to a tclutils tm tree that
# also contains common (e.g. .../tclutils/lib/tm). Set TUFETCH_NET=1 to include
# tufetch's real network round-trips.
set here [file dirname [file normalize [info script]]]

# --- where the modules come from (before any test runs) --------------------
# A green run says little if it loaded the wrong copy: an installed version, a
# module path from the environment, an old file beside a new one. So say
# where each library resolves -- found without loading anything -- and which
# module-path variables are set. (Idea 5 of ideen-tclutils-tkutils.md;
# 2026-09-19 a green suite depended on a TCL9_0_TM_PATH set in the shell.)
# tmFront dir -- put DIR at the front of the module path. A plain
# `tcl::tm::path add` does nothing when DIR is already listed -- e.g. from
# TCL8_6_TM_PATH, whose entries end up in reverse order. With the tree listed
# behind site-tcl, an installed copy of the same version then wins, and the
# suite tests that copy instead of the tree (reproduced 2026-09-19 with Tcl
# 8.6: TCL8_6_TM_PATH=<tree>:<site-tcl>).
proc tmFront {dir} {
    catch {tcl::tm::path remove $dir}
    tcl::tm::path add $dir
}

# ownTreesFirst root libs -- the module trees this suite is about: own lib/tm
# and the sibling libraries. Removed from TCL<ver>_TM_PATH so that the test
# processes started below put them in front themselves.
proc ownTrees {root libs} {
    set parent [file dirname $root]
    set dirs [list [file normalize [file join $root lib tm]]]
    foreach lib $libs {
        set var [string toupper $lib]_TM
        if {[info exists ::env($var)] && $::env($var) ne ""} {
            lappend dirs [file normalize $::env($var)]
        } else {
            foreach c [lsort -decreasing [glob -nocomplain -type d \
                    [file join $parent $lib* lib tm]]] {
                lappend dirs [file normalize $c]
                break
            }
        }
    }
    return [lsort -unique $dirs]
}
proc stripTreesFromEnv {dirs} {
    set sep [expr {$::tcl_platform(platform) eq "windows" ? ";" : ":"}]
    foreach var [array names ::env TCL*_TM_PATH] {
        set keep {}
        foreach d [split $::env($var) $sep] {
            if {$d ne "" && [file normalize $d] ni $dirs} { lappend keep $d }
        }
        set ::env($var) [join $keep $sep]
    }
}

proc showOrigins {root libs} {
    set dirs [ownTrees $root $libs]
    # the test processes: own trees not in the env path, so their own
    # `tcl::tm::path add` puts them in front
    stripTreesFromEnv $dirs
    # this interpreter: the same order the tests will see
    foreach d [lreverse $dirs] { tmFront $d }
    catch {package require __resolve_all_modules__}
    puts "Modules resolve to:"
    foreach lib $libs {
        set vers [lsort -dictionary [package versions $lib]]
        if {![llength $vers]} {
            puts [format "  %-10s NOT FOUND" $lib]
            continue
        }
        set v [lindex $vers end]
        set line [format "  %-10s %-8s %s" $lib $v [lindex [package ifneeded $lib $v] end]]
        if {[llength $vers] > 1} { append line "   (also: [lrange $vers 0 end-1])" }
        puts $line
    }
    foreach var {TCLUTILS_TM TKUTILS_TM TCL8_6_TM_PATH TCL9_0_TM_PATH TCLLIBPATH} {
        if {[info exists ::env($var)] && $::env($var) ne ""} {
            puts "  note: $var is set: $::env($var)"
        }
    }
    puts ""
}
showOrigins [file dirname $here] {tclutils}

set failed 0
foreach testfile [lsort [glob -nocomplain [file join $here *.test]]] {
    puts "=== [file tail $testfile]"
    set status [catch {exec [info nameofexecutable] $testfile 2>@1} out]
    puts $out
    set reportedFailures 0
    foreach line [split $out \n] {
        if {[regexp {Failed[ \t]+([0-9]+)} $line -> n] && $n > 0} { set reportedFailures $n }
    }
    if {$status || $reportedFailures > 0} { incr failed }
}
if {$failed > 0} { error "$failed test file(s) failed" }
puts "All test files passed"
