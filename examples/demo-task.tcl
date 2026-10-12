# demo-task.tcl -- tclutils::tutask without and with Tk
#
#   tclsh examples/demo-task.tcl        console: await, timeout, group, cancel
#   wish  examples/demo-task.tcl        plus a window: job with progress and
#                                       a Cancel button that runs finally
source [file join [file dirname [file normalize [info script]]] bootstrap.tcl]
package require tclutils::tutask
namespace import ::tclutils::tutask::*

# --- console part ------------------------------------------------------------

puts "1. await a timer:   [run apply {{} { await [timer 50 fertig] }}]"

puts "2. timeout:         [run apply {{} {
    try {
        await [timer 5000] -timeout 100
    } trap {TCLUTILS TUTASK TIMEOUT} {m} {
        return "abgebrochen ($m)"
    }
}}]"

puts "3. group, all:      [run apply {{} {
    set g [group]
    $g spawn apply {{} { sleep 80; return langsam }}
    $g spawn apply {{} { sleep 20; return schnell }}
    try { return [$g wait] } finally { $g destroy }
}}]"

set t [spawn apply {{} {
    try {
        sleep 10000
    } finally {
        puts "4. cancel:          finally ran"
    }
}}]
$t cancel
puts "                    state [$t state]"
$t destroy

puts "5. leaks:           [stats]"

if {[catch {package present Tk}]} { exit 0 }

# --- Tk part -----------------------------------------------------------------
#
# The handler only spawns; the task does the waiting. No vwait, no update.

set ::step 0
ttk::progressbar .bar -maximum 50 -variable ::step
ttk::label .status -text "Bereit."
ttk::button .go -text Start -command startJob
ttk::button .stop -text Abbrechen -state disabled -command {$::job cancel}
pack .bar -fill x -padx 8 -pady 8
pack .status -padx 8
pack .go .stop -side left -padx 8 -pady 8

proc startJob {} {
    .go state disabled
    .stop state !disabled
    set ::job [spawn apply {{} {
        try {
            for {set ::step 0} {$::step < 50} {incr ::step} {
                .status configure -text "Schritt $::step von 50"
                sleep 40
            }
            .status configure -text "Fertig."
        } trap {TCLUTILS TUTASK CANCELLED} {} {
            .status configure -text "Abgebrochen bei Schritt $::step."
            return -code error -errorcode {TCLUTILS TUTASK CANCELLED} cancelled
        } finally {
            .go state !disabled
            .stop state disabled
        }
    }}]
    $::job ondone {apply {{t} { $t destroy }}}
}
