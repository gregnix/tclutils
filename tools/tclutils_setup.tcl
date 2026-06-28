# setup.tcl -- makes the tclutils/tkutils libraries discoverable for Tcl.
#
# This file may live in two places:
#   a) directly in the directory that holds the library folders, e.g.
#        ~/lib/tcltk/setup.tcl   next to   tclutils-0.53.0/  tkutils-0.41.0/
#   b) inside a library, e.g.
#        ~/lib/tcltk/tclutils-0.53.0/tools/setup.tcl
#
# In both cases the root directory holding the library folders is located by
# walking upward from THIS file until tclutils-* / tkutils-* are found. No
# absolute paths are hard-wired.
#
# Usage in your own application:
#   source /path/to/setup.tcl
#   package require tclutils::tubin
#   package require tkutils::tkucsv

apply {{} {
    # Start at the directory of this file. Walk upward until a directory is
    # found that contains tclutils-* or tkutils-*.
    set dir [file dirname [file normalize [info script]]]
    set base $dir
    for {set i 0} {$i < 6} {incr i} {
        if {[llength [glob -nocomplain -directory $dir -type d tclutils-* tkutils-*]] > 0} {
            set base $dir
            break
        }
        set parent [file dirname $dir]
        if {$parent eq $dir} break
        set dir $parent
    }

    foreach lib {tclutils tkutils} {
        foreach d [lsort -decreasing -dictionary \
                [glob -nocomplain -directory $base -type d ${lib}-*]] {
            set tm [file join $d lib tm]
            if {[file isdirectory $tm]} {
                tcl::tm::path add $tm
                break   ;# only the highest version per library
            }
        }
    }
}}
