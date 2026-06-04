source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuimage
if {[llength $argv]} {
    set f [lindex $argv 0]
    set ch [open $f rb]; set data [read $ch]; close $ch
    puts "inspect $f -> [::tclutils::tuimage::inspect $data]"
} else {
    set png [binary format a8 "\x89PNG\r\n\x1a\n"]
    append png [binary format I 13] IHDR [binary format II 640 480]
    puts "synthetic PNG -> [::tclutils::tuimage::inspect $png]"
    set uri [::tclutils::tuimage::dataUri image/png "demo-bytes"]
    puts "dataUri        -> [string range $uri 0 38]..."
    puts "fromDataUri    -> [::tclutils::tuimage::fromDataUri $uri]"
    puts "(pass an image file as argument to inspect a real file)"
}
