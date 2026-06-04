set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tumath
namespace import ::tclutils::tumath::*
puts "clamp 12 0 10   = [clamp 12 0 10]"
puts "inRange 5 1 10  = [inRange 5 1 10]"
puts "percent 30 200  = [percent 30 200]"
puts "gcd 24 36       = [gcd 24 36]"
puts "lcm 4 6         = [lcm 4 6]"
puts "factorial 10    = [factorial 10]"
puts "roundTo pi 4    = [roundTo 3.14159265 4]"
