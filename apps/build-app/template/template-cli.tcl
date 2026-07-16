#!/usr/bin/env tclsh
# _template (CLI) -- a starting point for a build-app-packageable console app.
#
# A CLI app runs at source time and reads $argv. build-app copies it in as
# main.tcl directly, so NO -launch is needed:
#   build-app -kind cli -out mytool -basekit basekit-tcl \
#             -app _template -main template-cli.tcl
#
# See docs/guide/build-app-app-conventions.md.

package require Tcl 8.6-                              ;# (9) dash form: 8.6 and 9.x

# (2) locate our own files relative to [info script], never via cwd/absolute.
set dir [file dirname [file normalize [info script]]]

# (3) declare any module dependencies with `package require` (none here). A
#     dependency-free CLI tool can run on a bare system before anything is set up.

# (6) if the tool persists anything, write to a user/home location -- never next
#     to the executable (the zipkit is read-only):
#   set conf [file join [file normalize ~] .config mytool]

# main logic uses $argv:
if {[llength $argv] == 0} {
    puts "template-cli: no arguments (try: template-cli one two three)"
} else {
    puts "template-cli received [llength $argv] argument(s):"
    foreach a $argv { puts "  $a" }
}
