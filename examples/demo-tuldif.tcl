source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuldif
set ldif "dn: cn=Alice,dc=example,dc=com\ncn: Alice\nsn: Smith\nmail: alice@example.com\nmail: a.smith@example.com\n\ndn: cn=Bob,dc=example,dc=com\ncn: Bob\nmail: bob@example.com\n"
set entries [::tclutils::tuldif::parse $ldif]
puts "Entries: [llength $entries]"
foreach e $entries {
    puts "dn: [::tclutils::tuldif::dn $e]"
    foreach a [::tclutils::tuldif::attributes $e] {
        if {$a eq "dn"} continue
        puts "    $a: [join [::tclutils::tuldif::get $e $a] {, }]"
    }
}
