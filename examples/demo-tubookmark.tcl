source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tubookmark
set bms [list \
    [dict create title "Tcl & Tk" url https://tcl.tk/ folder "" tags {tcl lang} adddate ""] \
    [dict create title Fossil url https://core.tcl-lang.org/ folder Dev tags {} adddate ""] \
    [dict create title Manual url https://www.tcl-lang.org/man/ folder Dev/Docs tags {} adddate ""]]
set html [::tclutils::tubookmark::serialize $bms -title "Tcl Bookmarks"]
puts "--- serialized ---"
puts $html
puts "--- parsed back ---"
foreach b [::tclutils::tubookmark::parse $html] {
    puts [format "  %-8s %-28s %s" [dict get $b folder] [dict get $b url] [dict get $b title]]
}
