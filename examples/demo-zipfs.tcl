source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuzipfs

puts "zipfs available: [::tclutils::tuzipfs::available]"
if {![::tclutils::tuzipfs::available]} {
    puts "This demo needs Tcl 9 zipfs."
    exit 0
}

package require tclutils::tuzip
set tmp [file normalize [file join $::tclutils_example_dir .demo-zipfs]]
file delete -force $tmp
file mkdir $tmp
set f [open [file join $tmp hello.txt] w]
puts -nonewline $f "hello from zipfs"
close $f
set zip [file join $tmp demo.zip]
::tclutils::tuzip::create $zip [list [file join $tmp hello.txt]] -base $tmp

::tclutils::tuzipfs::withMounted $zip mp {
    puts "mounted at $mp"
    puts "files: [::tclutils::tuzipfs::listFiles $mp]"
    puts [::tclutils::tuzipfs::readFile [file join $mp hello.txt]]
}
file delete -force $tmp
