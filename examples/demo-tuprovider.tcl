source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuprovider

# tuprovider gives one interface over every storage backend. Here we use the
# built-in "local" backend on a throwaway directory.

set dir [file join [pwd] demo-tuprovider-tmp]
file mkdir [file join $dir sub]
set fh [open [file join $dir readme.txt] w] ; puts $fh "hello from tuprovider" ; close $fh
set fh [open [file join $dir sub inner.txt] w] ; puts $fh "one level down" ; close $fh

set p [::tclutils::tuprovider open local]

puts "Scheme(s) registered: [::tclutils::tuprovider::schemes]"
puts "Capabilities of local: [lsort [$p caps]]"
puts ""

puts "list $dir :"
foreach e [$p list $dir] {
    puts [format "  %-4s %-12s %s bytes" [dict get $e type] [dict get $e name] [dict get $e size]]
}
puts ""

puts "stat of readme.txt:"
puts "  [$p stat [file join $dir readme.txt]]"
puts ""

puts "get readme.txt:"
puts "  [string trim [$p get [file join $dir readme.txt]]]"
puts ""

# put + get round-trip
$p put [file join $dir written.txt] "written through the provider"
puts "after put, get written.txt:"
puts "  [$p get [file join $dir written.txt]]"

# tidy up
file delete -force $dir
