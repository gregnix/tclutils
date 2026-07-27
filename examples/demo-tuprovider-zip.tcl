source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuprovider
package require tclutils::tuprovider::zip
package require tclutils::tuzip

# The zip backend browses a ZIP archive through the same interface -- read-only,
# and it synthesizes directories from the flat member list.

set zip [file join [pwd] demo-tuprovider.zip]
::tclutils::tuzip::createMembers $zip {
    {name top.txt        content "at the archive root"}
    {name sub/inner.txt  content "one level down"}
    {name sub/deep/x.txt content "two levels down"}
}

set p [::tclutils::tuprovider open zip $zip]

puts "Capabilities of zip (read-only): [lsort [$p caps]]"
puts ""

puts "list / :"
foreach e [$p list /] {
    puts [format "  %-4s %s" [dict get $e type] [dict get $e name]]
}
puts "  (note: 'sub' is a synthesized directory -- no explicit entry for it)"
puts ""

puts "list /sub :"
foreach e [$p list /sub] {
    puts [format "  %-4s %s" [dict get $e type] [dict get $e name]]
}
puts ""

puts "get /sub/deep/x.txt:"
puts "  [$p get /sub/deep/x.txt]"
puts ""

puts "writing is refused (caps has no 'put'):"
if {[catch {$p put /new.txt data} e]} { puts "  -> $e" }

file delete -force $zip
