# Common bootstrap code for tclutils CLI scripts.
proc ::tclutils_cli_bootstrap {} {
    set script [file normalize [info script]]
    set dir [file dirname $script]
    set root [file dirname $dir]
    set tm [file join $root lib tm]
    tcl::tm::path add $tm
    if {[lsearch -exact $::auto_path $tm] < 0} {
        lappend ::auto_path $tm
    }
}
::tclutils_cli_bootstrap
