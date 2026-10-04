# all.tcl -- run every *.test in this directory, each in its own process.
# Exit 1 if a file reports failed tests, writes no summary, dies or hangs.
#
#   tclsh tests/all.tcl ?tcltest options, e.g. -match pattern?
#
# The runner itself is tclutils::tutestrun (own trees first, origin banner,
# per-file limit $env(TCLUTILS_TESTGRENZE), default 120 s). It is sourced
# from the tree under test -- own lib/tm, $env(TCLUTILS_TM) or the sibling
# tclutils checkout -- never from an installed copy.
set here [file dirname [file normalize [info script]]]
set root [file dirname $here]
set cands [list [file join $root lib tm]]
if {[info exists ::env(TCLUTILS_TM)]} { lappend cands $::env(TCLUTILS_TM) }
lappend cands {*}[lsort -decreasing [glob -nocomplain -type d \
    [file join [file dirname $root] tclutils* lib tm]]]
set runner ""
foreach d $cands {
    set found [lsort -dictionary [glob -nocomplain \
        [file join $d tclutils tutestrun-*.tm]]]
    if {[llength $found]} { set runner [lindex $found end]; break }
}
if {$runner eq ""} {
    puts stderr "all.tcl: tclutils::tutestrun not found (set TCLUTILS_TM)"
    exit 2
}
source -encoding utf-8 $runner
exit [::tclutils::tutestrun::run $here {tclutils} \
    -limitvar TCLUTILS_TESTGRENZE -argv $argv]
