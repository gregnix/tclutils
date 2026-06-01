package require Tcl 8.6-

set here [file dirname [file normalize [info script]]]
set failed 0
foreach testfile [lsort [glob -nocomplain [file join $here *.test]]] {
    puts "=== [file tail $testfile]"
    set status [catch {exec [info nameofexecutable] $testfile 2>@1} out]
    puts $out

    # tcltest often prints failures but still exits with status 0 unless the
    # individual test file explicitly calls exit.  Therefore the aggregator must
    # also inspect the summary line.
    set reportedFailures 0
    foreach line [split $out \n] {
        if {[regexp {Failed[ \t]+([0-9]+)} $line -> n] && $n > 0} {
            set reportedFailures $n
        }
    }

    if {$status || $reportedFailures > 0} {
        incr failed
    }
}
if {$failed > 0} {
    error "$failed test file(s) failed"
}
puts "All test files passed"
