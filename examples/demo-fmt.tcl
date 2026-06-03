source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tufmt
set text "The quick brown fox jumps over the lazy dog, and then keeps running far past the old wooden fence."
puts "--- width 30 ---"
puts [::tclutils::tufmt::reflow $text -width 30]
puts "--- indent preserved ---"
puts [::tclutils::tufmt::reflow "    a note that should wrap with a hanging indent kept on each line" -width 24]
