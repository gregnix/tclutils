source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tufold

set text {Tclutils provides small portable Unix-like utility helpers written in pure Tcl.}
puts [::tclutils::tufold::text $text -width 24 -words 1]
