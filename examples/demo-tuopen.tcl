source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tuopen
puts "open command per platform (not launched):"
puts "  linux:   [::tclutils::tuopen::command https://tcl.tk/ -platform unix -os Linux]"
puts "  macOS:   [::tclutils::tuopen::command https://tcl.tk/ -platform unix -os Darwin]"
puts "  windows: [::tclutils::tuopen::command https://tcl.tk/ -platform windows]"
puts "editor command per platform:"
puts "  linux:   [::tclutils::tuopen::editCommand notes.txt -platform unix -os Linux -editor {vi}]"
puts "  macOS:   [::tclutils::tuopen::editCommand notes.txt -platform unix -os Darwin]"
puts "  windows: [::tclutils::tuopen::editCommand notes.txt -platform windows]"
puts "config paths for app \"myapp\":"
puts "  linux:   [::tclutils::tuopen::configFile myapp settings.ini -platform unix -os Linux]"
puts "  macOS:   [::tclutils::tuopen::configFile myapp settings.ini -platform unix -os Darwin]"
puts "  windows: [::tclutils::tuopen::configFile myapp settings.ini -platform windows]"
# To actually open things, uncomment:
# ::tclutils::tuopen::launch https://tcl.tk/
# ::tclutils::tuopen::edit notes.txt
# ::tclutils::tuopen::openDir .
