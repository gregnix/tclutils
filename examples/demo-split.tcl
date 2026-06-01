source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tusplit

set src [file join $::tclutils_example_dir demo-split-input.txt]
::tclutils::common::writeFile $src "one\ntwo\nthree\nfour\nfive"
set outdir [file join $::tclutils_example_dir demo-split-out]
file delete -force $outdir
set files [::tclutils::tusplit::file $src -lines 2 -outdir $outdir -prefix part -suffix .txt]
puts $files
