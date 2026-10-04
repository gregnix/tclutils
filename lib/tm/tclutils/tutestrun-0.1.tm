# tclutils::tutestrun -- the shared all.tcl: run every *.test in its own process
# Description: test-suite runner: own trees first, origin banner, per-file time limit, summary and exit code
# Category: System · runtime
#
# tclutils, tkutils and ctrlutils had three copies of the same all.tcl, and
# each fix (time limit, own trees first, reading the tcltest summary) had to
# be made three times. One copy now:
#
#   # tests/all.tcl
#   set here [file dirname [file normalize [info script]]]
#   ... source tutestrun-*.tm from the tree under test (see docs) ...
#   exit [::tclutils::tutestrun::run $here {tkutils tclutils} \
#            -limitvar TKUTILS_TESTGRENZE -argv $argv]
#
# What run does, in this order:
#   1. Own trees first: DIR/../lib/tm and the sibling checkouts of LIBS
#      (or <LIB>_TM) are removed from TCL<ver>_TM_PATH for the test
#      processes and put in front here -- a plain [tcl::tm::path add] does
#      nothing for a tree that is already listed behind an installed copy of
#      the same version, which then gets tested instead.
#   2. Banner: where each of LIBS resolves (found without loading anything),
#      other versions beside it, and the module-path variables that are set.
#   3. Every *.test in DIR runs in its own process with ARGV (tcltest options
#      such as -match), under a wall-clock limit: -limit seconds, or the
#      environment variable named by -limitvar. A hung file is killed.
#   4. Summary: a file with failed tests, no tcltest summary line, a non-zero
#      exit or a hang is listed. Returns 1 then, else 0 -- tcltest itself ends
#      a file with exit code 0 even when tests FAILED.
#
# Pure Tcl, no Tk. Tcl 8.6+ and 9.x.

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tutestrun {
    namespace export run
    variable version 0.1
}

proc ::tclutils::tutestrun::_tmFront {dir} {
    catch {tcl::tm::path remove $dir}
    tcl::tm::path add $dir
}

# The module trees the suite is about: own lib/tm and the sibling libraries.
proc ::tclutils::tutestrun::_ownTrees {root libs} {
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

proc ::tclutils::tutestrun::_stripEnv {dirs} {
    set sep [expr {$::tcl_platform(platform) eq "windows" ? ";" : ":"}]
    foreach var [array names ::env TCL*_TM_PATH] {
        set keep {}
        foreach d [split $::env($var) $sep] {
            if {$d ne "" && [file normalize $d] ni $dirs} { lappend keep $d }
        }
        set ::env($var) [join $keep $sep]
    }
}

proc ::tclutils::tutestrun::_origins {root libs} {
    set dirs [_ownTrees $root $libs]
    _stripEnv $dirs
    foreach d [lreverse $dirs] { _tmFront $d }
    catch {package require __resolve_all_modules__}
    puts "Modules resolve to:"
    foreach lib $libs {
        set vers [lsort -dictionary [package versions $lib]]
        if {![llength $vers]} {
            puts [format "  %-10s NOT FOUND" $lib]
            continue
        }
        set v [lindex $vers end]
        set line [format "  %-10s %-8s %s" $lib $v \
            [lindex [package ifneeded $lib $v] end]]
        if {[llength $vers] > 1} { append line "   (also: [lrange $vers 0 end-1])" }
        puts $line
    }
    set vars [list TCL8_6_TM_PATH TCL9_0_TM_PATH TCLLIBPATH]
    foreach lib $libs { lappend vars [string toupper $lib]_TM }
    foreach var [lsort -unique $vars] {
        if {[info exists ::env($var)] && $::env($var) ne ""} {
            puts "  note: $var is set: $::env($var)"
        }
    }
    puts ""
}

# Run one file under a timer. Returns {art status out}, art = gelaufen |
# haenger | nichtgestartet. ([exec] alone would wait forever.)
proc ::tclutils::tutestrun::_runFile {exe file argv limit} {
    variable done
    variable text
    if {[catch {open [list | $exe $file {*}$argv 2>@1] r} ch]} {
        return [list nichtgestartet -1 $ch]
    }
    set pid [pid $ch]
    chan configure $ch -blocking 0 -translation auto
    # Tcl 9 reads strictly: one byte that is not valid in the system encoding
    # (a program started by a test writing in the console code page, say)
    # raised an error in the handler on every event, and the file "hung"
    # until the limit. Replace such bytes instead (8.6 has no -profile).
    catch {chan configure $ch -profile replace}
    set text($ch) ""
    unset -nocomplain done($ch)
    chan event $ch readable [list apply {{ch} {
        if {[catch {read $ch} chunk]} {
            # last resort: take the rest as bytes
            catch {chan configure $ch -translation binary}
            if {[catch {read $ch} chunk]} {
                append ::tclutils::tutestrun::text($ch) "\n(read error: $chunk)"
                set ::tclutils::tutestrun::done($ch) fertig
                return
            }
        }
        append ::tclutils::tutestrun::text($ch) $chunk
        if {[chan eof $ch]} { set ::tclutils::tutestrun::done($ch) fertig }
    }} $ch]
    set timer [after [expr {$limit * 1000}] \
        [list set ::tclutils::tutestrun::done($ch) haenger]]
    vwait ::tclutils::tutestrun::done($ch)
    after cancel $timer
    chan event $ch readable {}
    set art $done($ch)
    set status 0
    set out $text($ch)
    if {$art eq "haenger"} {
        if {$::tcl_platform(platform) eq "windows"} {
            catch {exec taskkill /PID $pid /T /F}
        } else {
            catch {exec kill -TERM $pid}
            after 300
            catch {exec kill -KILL $pid}
        }
        catch {close $ch}
        append out "\n(stopped after $limit s -- the file did not end)"
        set status -1
    } else {
        set art gelaufen
        chan configure $ch -blocking 1
        if {[catch {close $ch} err opt]} {
            set ec ""
            if {[dict exists $opt -errorcode]} { set ec [dict get $opt -errorcode] }
            switch -- [lindex $ec 0] {
                CHILDSTATUS { set status [lindex $ec 2] }
                CHILDKILLED { set status -1; append out "\n(killed: $err)" }
                NONE        { set status 0 }
                default     { set status -1; append out "\n$err" }
            }
        }
    }
    unset -nocomplain text($ch) done($ch)
    return [list $art $status $out]
}

# Evaluate one file's output: "" if fine, else the reason.
proc ::tclutils::tutestrun::_verdict {art status out limit} {
    switch -- $art {
        haenger        { return "hang after ${limit}s" }
        nichtgestartet { return "could not start" }
    }
    set failed -1
    foreach line [split $out \n] {
        if {[regexp {\tTotal\t\d+\tPassed\t\d+\tSkipped\t\d+\tFailed\t(\d+)} \
                $line -> n]} {
            set failed $n
        }
    }
    if {$failed < 0}  { return "no summary" }
    if {$failed > 0}  { return "$failed failed" }
    if {$status != 0} { return "exit code / error" }
    return ""
}

# Run the suite in DIR. Returns the exit code: 0 all fine, 1 otherwise.
proc ::tclutils::tutestrun::run {dir libs args} {
    array set o {-limit 120 -limitvar "" -argv {}}
    foreach {k v} $args {
        if {![info exists o($k)]} {
            return -code error -errorcode [list TCLUTILS TUTESTRUN OPTION $k] \
                "unknown option \"$k\"\nKnown: -argv -limit -limitvar"
        }
        set o($k) $v
    }
    set limit $o(-limit)
    if {$o(-limitvar) ne "" && [info exists ::env($o(-limitvar))]} {
        set v $::env($o(-limitvar))
        if {[string is integer -strict $v] && $v > 0} { set limit $v }
    }
    set dir [file normalize $dir]
    _origins [file dirname $dir] $libs
    set bad {}
    foreach f [lsort [glob -nocomplain -directory $dir *.test]] {
        set name [file tail $f]
        puts "=== $name"
        lassign [_runFile [info nameofexecutable] $f $o(-argv) $limit] art status out
        puts $out
        set why [_verdict $art $status $out $limit]
        if {$why ne ""} { lappend bad "$name ($why)" }
    }
    if {[llength $bad]} {
        puts "\nFiles with problems:"
        foreach b $bad { puts "  $b" }
        return 1
    }
    puts "\nAll test files passed"
    return 0
}

package provide tclutils::tutestrun 0.1
