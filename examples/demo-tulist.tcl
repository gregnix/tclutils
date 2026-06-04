set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tulist
namespace import ::tclutils::tulist::*
set l {3 1 4 1 5 9 2 6}
puts "list:    $l"
puts "unique:  [unique $l]"
puts "chunk 3: [chunk $l 3]"
puts "sum/avg: [sum $l] / [avg $l]"
puts "min/max: [min $l] / [max $l]"
puts "squares: [map $l {apply {{x} {expr {$x*$x}}}}]"
puts "evens:   [filter $l {apply {{x} {expr {$x%2==0}}}}]"
puts "zip:     [zip {a b c} {1 2 3}]"
