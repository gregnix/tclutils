# Shared bootstrap for examples.
# Makes the local .tm modules visible when demos are run from the source tree.
set here [file dirname [file normalize [info script]]]
set root [file dirname $here]
set ::tclutils_example_dir $here
set ::tclutils_root $root
tcl::tm::path add [file join $root lib tm]
lappend auto_path [file join $root lib tm]
