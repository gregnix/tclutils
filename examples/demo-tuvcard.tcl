source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuvcard
set vcf "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Alice Smith\r\nEMAIL;TYPE=work:alice@example.com\r\nEMAIL;TYPE=home:alice@home.com\r\nTEL;TYPE=cell:+49 170 1234567\r\nEND:VCARD\r\nBEGIN:VCARD\r\nVERSION:3.0\r\nFN:Bob Jones\r\nEMAIL:bob@example.com\r\nEND:VCARD\r\n"
set cards [::tclutils::tuvcard::parse $vcf]
puts "Contacts: [llength $cards]"
foreach c $cards {
    puts "[::tclutils::tuvcard::fullName $c]"
    foreach m [::tclutils::tuvcard::get $c EMAIL] { puts "    email: $m" }
    foreach t [::tclutils::tuvcard::get $c TEL]   { puts "    tel:   $t" }
}
