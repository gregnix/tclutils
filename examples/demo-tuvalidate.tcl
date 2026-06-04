set here [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $here .. lib tm]]
package require tclutils::tuvalidate
foreach {label val test} {
    email a@b.com   email
    email broken    email
    ipv4  10.0.0.1  ipv4
    ipv4  9.9.9.300 ipv4
    port  8080      port
    url   https://x.org/y url
} {
    puts [format "%-6s %-16s -> %d" $test $val [::tclutils::tuvalidate::$test $val]]
}
puts "length \"abc\" 1 5  -> [::tclutils::tuvalidate::length abc 1 5]"
puts "inList b {a b c}   -> [::tclutils::tuvalidate::inList b {a b c}]"
