#!/usr/bin/env tclsh
# Thin CLI for tclutils::tupngdraw. The primary interface is the Tcl library
# (see tupngdraw(n)); this wrapper renders a self-contained demo image so the
# module can be exercised from the shell.
source [file join [file dirname [info script]] _bootstrap.tcl]
package require tclutils::tupngdraw

proc usage {} {
    puts stderr "usage: tupngdraw demo <out.png> ?-width N? ?-height N?"
    exit 2
}

set cmd [lindex $argv 0]
if {$cmd ne "demo"} usage
set out [lindex $argv 1]
if {$out eq ""} usage
set opts [lrange $argv 2 end]
set W 320; set H 200
foreach {k v} $opts {
    switch -- $k {
        -width  { set W $v }
        -height { set H $v }
        default { usage }
    }
}

set p [::tclutils::tupngdraw::new -width $W -height $H -background {245 245 245}]

# panel
$p setfill {255 255 255}
$p setstroke {60 60 60}
$p setlinewidth 2
$p rect 10 10 [expr {$W-10}] [expr {$H-10}] -fill 1

# overlapping translucent discs (show alpha compositing)
$p setfill {220 40 40 150};  $p circle [expr {int($W*0.40)}] [expr {int($H*0.45)}] 55 -fill 1 -outline 0
$p setfill {40 120 220 150}; $p circle [expr {int($W*0.55)}] [expr {int($H*0.45)}] 55 -fill 1 -outline 0
$p setfill {40 200 90 150};  $p circle [expr {int($W*0.475)}] [expr {int($H*0.62)}] 55 -fill 1 -outline 0

# a filled triangle and a couple of strokes
$p setfill {255 200 0}
$p polygon [list [expr {int($W*0.70)}] 30 [expr {int($W*0.92)}] 30 [expr {int($W*0.81)}] 90] -fill 1
$p setstroke {30 30 30}
$p setlinewidth 1
$p line 20 [expr {$H-25}] [expr {$W-20}] [expr {$H-25}]
$p setlinewidth 3
$p line 20 [expr {$H-40}] [expr {int($W*0.5)}] [expr {$H-70}]

$p write $out -compression 9
$p destroy
puts $out
