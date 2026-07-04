source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuxxhash
namespace import ::tclutils::tuxxhash::*

puts "== xxHash32 =="
foreach s {"" "abc" "The quick brown fox jumps over the lazy dog"} {
    puts "  xxh32(\"$s\") = [xxh32 $s]"
}
puts "  with seed 12345: [xxh32 {The quick brown fox jumps over the lazy dog} 12345]"

puts "\n== hashing a file =="
set tmp [file join [file dirname [info script]] demo-xxhash.tcl]
puts "  xxh32file([file tail $tmp]) = [xxh32file $tmp]"

puts "\n== de-duplication bucketing =="
# group identical byte contents cheaply by their hash
set docs {
    {a.txt "Rechnung 042 Mueller GmbH"}
    {b.txt "Rechnung 042 Mueller GmbH"}
    {c.txt "Lieferschein 7 Meier KG"}
}
array set bucket {}
foreach d $docs {
    lassign $d name content
    lappend bucket([xxh32 $content]) $name
}
foreach h [array names bucket] {
    set names $bucket($h)
    if {[llength $names] > 1} {
        puts "  duplicates (h=$h): [join $names {, }]"
    } else {
        puts "  unique     (h=$h): [lindex $names 0]"
    }
}
