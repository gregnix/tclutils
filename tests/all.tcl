package require Tcl 8.6-
# Run every *.test in this directory. Set TCLUTILS_TM to a tclutils tm tree that
# also contains common (e.g. .../tclutils/lib/tm). Set TUFETCH_NET=1 to include
# tufetch's real network round-trips.
set here [file dirname [file normalize [info script]]]
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
