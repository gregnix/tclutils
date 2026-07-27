source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tuprovider
package require tclutils::tuprovider::dav

# The dav backend browses a WebDAV server through the same interface. A live
# demo would need a running server and credentials, e.g.:
#
#     set p [::tclutils::tuprovider open dav https://host/dav/ -user me -password pw]
#     foreach e [$p list /files/] { puts [dict get $e name] }
#
# To keep this demo self-contained and offline, we stub the tudav layer so the
# adapter's own logic -- caps and the href -> entry mapping -- can be shown
# without a network. Overriding tudav AFTER requiring the package replaces the
# real HTTP calls.

namespace eval ::tclutils::tudav {}
proc ::tclutils::tudav::client {url args}          { return stub }
proc ::tclutils::tudav::destroy {c}                { return }
proc ::tclutils::tudav::listCollections {c args}   { return {{href /dav/photos/} {href /dav/notes/}} }
proc ::tclutils::tudav::listResources   {c args}   { return {{href /dav/todo.txt} {href /dav/report.pdf}} }
proc ::tclutils::tudav::getProperties   {c args}   { return {} }

set p [::tclutils::tuprovider open dav http://example/dav/]

puts "Capabilities of dav: [lsort [$p caps]]"
puts "  (list/stat/get/put/delete -- no mkdir/move/copy, honestly reported)"
puts ""

puts "list /dav/ (collections become dirs, resources become files):"
foreach e [$p list /dav/] {
    puts [format "  %-4s %s" [dict get $e type] [dict get $e name]]
}
puts ""
puts "Note how each href tail became a clean leaf name"
puts "(/dav/photos/ -> photos, /dav/todo.txt -> todo.txt)."
