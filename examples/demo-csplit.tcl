source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tucsplit

set src [file join $::tclutils_example_dir demo-csplit-input.md]
::tclutils::common::writeFile $src "Intro\n# One\nText one\n# Two\nText two"
set outdir [file join $::tclutils_example_dir demo-csplit-out]
file delete -force $outdir
set files [::tclutils::tucsplit::file $src {^# } -outdir $outdir -prefix chapter -suffix .md]
puts $files
