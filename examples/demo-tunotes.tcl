source [file join [file dirname [info script]] bootstrap.tcl]
package require tclutils::tunotes
set store {}
set work    [::tclutils::tunotes::create store "Work" "" {project}]
set tasks   [::tclutils::tunotes::create store "Tasks" "" {todo} $work]
set release [::tclutils::tunotes::create store "Release 1.0" "ship it" {todo urgent} $tasks]
set home    [::tclutils::tunotes::create store "Home" "" {personal}]
::tclutils::tunotes::addTag store $home shopping
puts "Notes: [::tclutils::tunotes::count $store], roots: [llength [::tclutils::tunotes::roots $store]]"
foreach id [::tclutils::tunotes::roots $store] {
    puts "- [dict get [::tclutils::tunotes::get $store $id] title]"
    foreach c [::tclutils::tunotes::descendants $store $id] {
        set n [::tclutils::tunotes::get $store $c]
        puts "    [string repeat {  } [::tclutils::tunotes::depth $store $c]][dict get $n title]  tags=[dict get $n tags]"
    }
}
puts "Tagged 'todo': [llength [::tclutils::tunotes::byTag $store todo]] note(s)"
puts "Path to Release: [::tclutils::tunotes::path $store $release]"
