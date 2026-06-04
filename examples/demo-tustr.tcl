set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tustr
namespace import ::tclutils::tustr::*
puts "toCamel:   [toCamel {my-cool_var name}]"
puts "toSnake:   [toSnake MyCoolVar]"
puts "slugify:   [slugify {Hello, World!}]"
puts "truncate:  [truncate {the quick brown fox} 12]"
puts "padLeft:   '[padLeft 42 6 0]'"
puts "center:    '[center hi 8 -]'"
puts "splitTrim: [splitTrim { a , b ,, c } ,]"
puts "count ab:  [count abababa ab]"
