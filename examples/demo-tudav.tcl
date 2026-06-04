source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tudav
# Live demo against a real CardDAV server. Set the environment variables:
#   DAV_URL=https://host/addressbooks/user/contacts/  DAV_USER=... DAV_PASS=...
# (For self-hosted Radicale, http://127.0.0.1:5232/... also works dependency-free;
#  https pulls in the tls package automatically.)
if {![info exists ::env(DAV_URL)]} {
    puts "Set DAV_URL (and optionally DAV_USER/DAV_PASS) to run this live, e.g.:"
    puts "  DAV_URL=http://127.0.0.1:5232/alice/contacts/ DAV_USER=alice DAV_PASS=pw \\"
    puts "    tclsh [file tail [info script]]"
    exit 0
}
set args [list $::env(DAV_URL)]
if {[info exists ::env(DAV_USER)]} { lappend args -user $::env(DAV_USER) }
if {[info exists ::env(DAV_PASS)]} { lappend args -password $::env(DAV_PASS) }
set c [::tclutils::tudav::client {*}$args]
set res [::tclutils::tudav::listResources $c]
puts "found [llength $res] resource(s):"
foreach r $res { puts "  [dict get $r href]  etag=[dict get $r etag]" }
if {[llength $res]} {
    set body [::tclutils::tudav::get $c [dict get [lindex $res 0] href]]
    puts "--- first resource (status [::tclutils::tudav::lastStatus $c]) ---"
    puts $body
}
::tclutils::tudav::destroy $c
