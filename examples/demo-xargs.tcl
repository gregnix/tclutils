source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuxargs

proc showBatch {args} { puts "batch: $args" }
::tclutils::tuxargs::apply {a b c d e} showBatch -n 2 -collect 0
