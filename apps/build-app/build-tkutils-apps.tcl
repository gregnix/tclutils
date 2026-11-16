#!/usr/bin/env wish9.0
# build-tkutils-apps.tcl -- build the tkutils apps as programs, one after the
# other, with build-app.tcl next to this script.
#
#     wish9.0 build-tkutils-apps.tcl -basekit FILE ?-outdir DIR? ?-tkutils DIR?
#                                    ?-only {name ...}? ?build-app options ...?
#
#   -basekit FILE   a static wish 9 basekit (BAWT, magicsplat); for Windows
#                   programs the Windows basekit (output then gets .exe)
#   -outdir DIR     where the programs go (default: ./programs)
#   -tkutils DIR    the tkutils checkout (default: next to tclutils)
#   -only NAMES     only these apps (folder names, e.g. {notes-app csv-editor})
# Every other option goes to build-app as is (-extlib, -stdlibfrom, -probe ...).
# Run it with a display (the prober and the start check open the windows).
# At the end a table: app, size, and whether the program started.

if {![package vsatisfies [info patchlevel] 9.0-]} {
    puts stderr "build-tkutils-apps: needs Tcl 9 (this is Tcl [info patchlevel])"
    exit 2
}

set here [file dirname [file normalize [info script]]]
set tclutils [file dirname [file dirname $here]]

# folder and entry script of each app
set apps {
    adressbuch          adressbuch.tcl
    csv-editor          csv_editor.tcl
    knowledge           knowledge-base.tcl
    notes-app           notes_app.tcl
    sqlite-editor       sqlite-editor.tcl
    tdbc-sqlite-editor  tdbc-sqlite-editor.tcl
    postgresql-editor   postgresql-editor.tcl
    oracle-editor       oracle-editor.tcl
    search-replace-tool search_replace_tool.tcl
    tkdevtools          tkdevtools.tcl
    tkudesigner         tkudesigner.tcl
    launcher            launcher.tcl
}

array set o [list -basekit "" -outdir programs -only {} \
    -tkutils [file join [file dirname $tclutils] tkutils]]
set pass {}
if {[llength $argv] % 2} { puts stderr "build-tkutils-apps: each option needs a value"; exit 2 }
foreach {k v} $argv {
    if {[info exists o($k)]} { set o($k) $v } else { lappend pass $k $v }
}
if {$o(-basekit) eq ""} { puts stderr "build-tkutils-apps: -basekit is required"; exit 2 }
if {![file isdirectory [file join $o(-tkutils) apps]]} {
    puts stderr "build-tkutils-apps: no tkutils at $o(-tkutils) (give -tkutils DIR)"
    exit 2
}
file mkdir $o(-outdir)
set exe [expr {[string match -nocase *.exe [file tail $o(-basekit)]]
    || [string match -nocase *win* [file tail $o(-basekit)]] ? ".exe" : ""}]

set rows {}
foreach {name main} $apps {
    if {[llength $o(-only)] && $name ni $o(-only)} continue
    set out [file join $o(-outdir) $name$exe]
    puts "===== $name"
    set cmd [list [info nameofexecutable] [file join $here build-app.tcl] \
        -out $out -basekit [file normalize $o(-basekit)] \
        -app [file join $o(-tkutils) apps $name] -main $main \
        -tm [file join $tclutils lib tm] -tm [file join $o(-tkutils) lib tm] {*}$pass]
    # a Windows program does not start here: no start check
    if {$exe ne "" && $::tcl_platform(platform) ne "windows"} { lappend cmd -smoke 0 }
    set ok [expr {![catch {exec {*}$cmd 2>@1} log]}]
    puts $log
    set size [expr {[file exists $out] ? "[expr {[file size $out] / 1048576.0}]" : ""}]
    set state [expr {$ok ? ([string match "*SMOKE OK*" $log] ? "starts" : "built") : "FAILED"}]
    lappend rows [list $name [expr {$size eq "" ? "-" : [format %.1f $size]}] $state]
}
puts "\napp                   MB    result"
foreach r $rows { puts [format "%-20s %5s   %s" {*}$r] }
puts "programs in [file normalize $o(-outdir)]"
exit [expr {[lsearch -index 2 $rows FAILED] >= 0}]
