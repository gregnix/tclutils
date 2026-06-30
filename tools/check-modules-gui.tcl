#!/usr/bin/env wish
# check-modules-gui -- a Tk front-end for tools/check-modules.tcl
# Description: browse a tclutils/tkutils module hygiene report and edit .tm files
#
# Shows the full human report from check-modules.tcl, lists every module from
# its -manifest output in a sortable/filterable table, and opens the selected
# .tm file in an embedded editor with save.  Standalone: needs only Tcl/Tk,
# no external packages and no TCLLIBPATH setup.
#
# Usage:  wish check-modules-gui.tcl ?repo-root?
#
# MIT.  Tcl/Tk 8.6+ and 9.x.

package require Tcl 8.6-
package require Tk 8.6-

namespace eval cmgui {
    variable S
    array set S {
        root     ""
        interp   "tclsh"
        toolrel  "tools/check-modules.tcl"
        curpath  ""
        curname  ""
        dirty    0
        sortcol  package
        sortdir  -increasing
    }
    variable W
    array set W {}
    variable ROWS {}   ;# list of dicts: name version category test doc man deps path desc
}

# ---------------------------------------------------------------- exec helper

# Run a child interpreter command.  Returns its output.  A non-zero exit
# (check-modules signals hygiene that way) or stderr-only output is NOT an
# error -- the output is still valid.  Only a genuine launch failure raises.
# Run a child interpreter command and return its stdout, decoded as UTF-8
# regardless of the ambient locale.  Reading through a pipe (rather than exec)
# means stderr stays out of the result and exec's "child process exited
# abnormally" sentinel is never appended.  A non-zero exit (check-modules
# signals hygiene that way) is expected; only a genuine launch failure raises.
proc cmgui::runExec {cmd} {
    if {[catch {open [list | {*}$cmd] r} chan]} {
        return -code error -errorcode {CMGUI EXEC FAILED} $chan
    }
    fconfigure $chan -encoding utf-8
    set out [read $chan]
    if {[catch {close $chan} cerr copts]} {
        switch -- [lindex [dict get $copts -errorcode] 0] {
            CHILDSTATUS - NONE {}
            default { return -code error -errorcode {CMGUI EXEC FAILED} $cerr }
        }
    }
    return $out
}

proc cmgui::toolPath {} {
    variable S
    return [file join $S(root) {*}[file split $S(toolrel)]]
}

proc cmgui::looksLikeRepo {dir} {
    expr {[file exists [file join $dir {*}[file split [set ::cmgui::S(toolrel)]]]]
          && [file isdirectory [file join $dir lib tm]]}
}

# ------------------------------------------------------------------- data load

proc cmgui::refresh {} {
    variable S
    if {$S(root) eq ""} { return }
    set tool [cmgui::toolPath]
    if {![file exists $tool]} {
        cmgui::showError "Tool not found" \
            "check-modules.tcl was not found at:\n\n$tool\n\nPick a repository root that contains tools/check-modules.tcl."
        return
    }
    # env for module-path resolution (harmless if the tool does not use it)
    set ::env(TCLUTILS_TM) [file join $S(root) lib tm]
    set ::env(TKUTILS_TM)  [file join $S(root) lib tm]
    if {[catch {cmgui::loadManifest} err]} {
        cmgui::showError "Manifest failed" $err ; return
    }
    if {[catch {cmgui::loadReport} err]} {
        cmgui::showError "Report failed" $err ; return
    }
    cmgui::setStatus "Loaded [llength $::cmgui::ROWS] modules from $S(root)"
}

proc cmgui::loadManifest {} {
    variable S ; variable ROWS
    set tool [cmgui::toolPath]
    # pipe read excludes stderr, so the TSV on stdout stays clean
    set tsv [cmgui::runExec [list $S(interp) $tool $S(root) -manifest tsv]]
    set lines [split [string trim $tsv \n] \n]
    if {[llength $lines] < 1} { set ROWS {} ; cmgui::fillTable ; return }
    set header [split [lindex $lines 0] \t]
    set ROWS {}
    foreach line [lrange $lines 1 end] {
        if {$line eq ""} continue
        set f [split $line \t]
        set row [dict create]
        foreach col $header val $f { dict set row $col $val }
        lappend ROWS $row
    }
    cmgui::fillTable
}

proc cmgui::loadReport {} {
    variable S ; variable W
    set tool [cmgui::toolPath]
    set rep [cmgui::runExec [list $S(interp) $tool $S(root)]]
    set t $W(report)
    $t configure -state normal
    $t delete 1.0 end
    $t insert end $rep
    $t configure -state disabled
}

# ------------------------------------------------------------------- the table

proc cmgui::flag {row key} {
    expr {[dict exists $row $key] && [string equal -nocase [dict get $row $key] "Y"] ? "\u2713" : "\u00b7"}
}

proc cmgui::fillTable {} {
    variable W ; variable ROWS ; variable S
    set tv $W(tree)
    $tv delete [$tv children {}]
    set filt [string trim [string tolower [$W(filter) get]]]
    set sorted [cmgui::sortRows $ROWS]
    set nlack 0 ; set nshown 0
    foreach row $sorted {
        set name [dict get $row package]
        set cat  [expr {[dict exists $row category] ? [dict get $row category] : ""}]
        if {$filt ne "" && ![string match *$filt* [string tolower "$name $cat"]]} continue
        set short [lindex [split $name ::] end]
        set vals [list $name \
                       [expr {[dict exists $row version] ? [dict get $row version] : ""}] \
                       $cat \
                       [cmgui::flag $row test] \
                       [cmgui::flag $row doc] \
                       [cmgui::flag $row man]]
        set lack [expr {[cmgui::flag $row test] eq "\u00b7" ||
                        [cmgui::flag $row doc]  eq "\u00b7" ||
                        [cmgui::flag $row man]  eq "\u00b7"}]
        set tag [expr {$lack ? "lack" : "ok"}]
        set id [$tv insert {} end -values $vals -tags $tag]
        # stash full path + meta for this item
        set ::cmgui::item2row($id) $row
        if {$lack} { incr nlack }
        incr nshown
    }
    cmgui::setStatus "$nshown shown / [llength $ROWS] modules \u2014 $nlack missing test/doc/man"
}

proc cmgui::sortRows {rows} {
    variable S
    set col $S(sortcol)
    return [lsort -dictionary $S(sortdir) -command {apply {{col a b} {
        set av [expr {[dict exists $a $col] ? [dict get $a $col] : ""}]
        set bv [expr {[dict exists $b $col] ? [dict get $b $col] : ""}]
        string compare -nocase $av $bv
    }} $col} $rows]
}

proc cmgui::onHeading {col} {
    variable S
    if {$S(sortcol) eq $col} {
        set S(sortdir) [expr {$S(sortdir) eq "-increasing" ? "-decreasing" : "-increasing"}]
    } else {
        set S(sortcol) $col ; set S(sortdir) -increasing
    }
    cmgui::fillTable
}

proc cmgui::onSelect {} {
    variable W
    set tv $W(tree)
    set sel [$tv selection]
    if {$sel eq ""} return
    set id [lindex $sel 0]
    if {![info exists ::cmgui::item2row($id)]} return
    set row $::cmgui::item2row($id)
    set rel [dict get $row path]
    set full [file join $::cmgui::S(root) $rel]
    cmgui::openModule $full $row
}

# ------------------------------------------------------------------ the editor

proc cmgui::maybeDiscard {} {
    variable S
    if {!$S(dirty)} { return 1 }
    set ans [tk_messageBox -type yesnocancel -icon question -title "Unsaved changes" \
        -message "Module \"$S(curname)\" has unsaved changes." \
        -detail "Save before switching?"]
    switch -- $ans {
        yes    { return [cmgui::saveModule] }
        no     { return 1 }
        cancel { return 0 }
    }
}

proc cmgui::openModule {full row} {
    variable W ; variable S
    if {![cmgui::maybeDiscard]} {
        # re-select the previous item visually? simplest: leave selection, bail
        return
    }
    if {[catch {
        set fh [open $full r]
        fconfigure $fh -encoding utf-8 -translation lf
        set data [read $fh]
        close $fh
    } err]} {
        cmgui::showError "Open failed" "Could not read:\n$full\n\n$err" ; return
    }
    set e $W(edit)
    $e configure -state normal
    $e delete 1.0 end
    $e insert end $data
    $e edit reset
    $e edit modified 0
    set S(curpath) $full
    set S(curname) [dict get $row package]
    set S(dirty) 0
    # info line
    set cat  [expr {[dict exists $row category] ? [dict get $row category] : ""}]
    set desc [expr {[dict exists $row description] ? [dict get $row description] : ""}]
    $W(info) configure -text "$S(curname)   \u2022   $cat\n$desc"
    cmgui::updateTitle
    $W(nb) select $W(edittab)
    cmgui::setStatus "Opened [file tail $full]"
}

proc cmgui::saveModule {} {
    variable W ; variable S
    if {$S(curpath) eq ""} { return 1 }
    if {[catch {
        set fh [open $S(curpath) w]
        fconfigure $fh -encoding utf-8 -translation lf
        puts -nonewline $fh [$W(edit) get 1.0 "end - 1 char"]
        close $fh
    } err]} {
        cmgui::showError "Save failed" "Could not write:\n$S(curpath)\n\n$err" ; return 0
    }
    $W(edit) edit modified 0
    set S(dirty) 0
    cmgui::updateTitle
    cmgui::setStatus "Saved [file tail $S(curpath)]"
    return 1
}

proc cmgui::onModified {} {
    variable W ; variable S
    if {[$W(edit) edit modified]} {
        if {!$S(dirty)} { set S(dirty) 1 ; cmgui::updateTitle }
    }
}

proc cmgui::updateTitle {} {
    variable S
    set star [expr {$S(dirty) ? "*" : ""}]
    set who  [expr {$S(curname) ne "" ? " \u2014 $S(curname)$star" : ""}]
    wm title . "check-modules-gui$who"
}

# -------------------------------------------------------------- misc UI helpers

proc cmgui::setStatus {msg} {
    variable W
    $W(status) configure -text $msg
}

proc cmgui::showError {title msg} {
    set w .err[clock clicks]
    toplevel $w
    wm title $w $title
    ttk::label $w.l -text $title -font {TkDefaultFont 10 bold} -padding {10 8 10 2}
    grid $w.l -sticky w
    set t [text $w.t -width 90 -height 16 -wrap word -font TkFixedFont]
    set sb [ttk::scrollbar $w.sb -orient vertical -command [list $t yview]]
    $t configure -yscrollcommand [list $sb set]
    grid $t $sb -sticky nsew -padx {10 0}
    $t insert end $msg
    $t configure -state disabled
    ttk::button $w.b -text "Close" -command [list destroy $w]
    grid $w.b -sticky e -padx 10 -pady 8 -columnspan 2
    grid rowconfigure $w 1 -weight 1
    grid columnconfigure $w 0 -weight 1
}

proc cmgui::browseRoot {} {
    variable S
    set d [tk_chooseDirectory -title "Select repository root" \
              -initialdir [expr {$S(root) ne "" ? $S(root) : [pwd]}]]
    if {$d eq ""} return
    set S(root) $d
    cmgui::refresh
}

# --------------------------------------------------------------------- build UI

proc cmgui::buildUI {} {
    variable W ; variable S

    option add *tearOff 0
    wm title . "check-modules-gui"
    wm geometry . 1100x720

    # menu
    set m [menu .menu]
    . configure -menu $m
    set mf [menu $m.file]
    $m add cascade -label "File" -menu $mf
    $mf add command -label "Open repository root\u2026" -command cmgui::browseRoot -accelerator "Ctrl+O"
    $mf add command -label "Reload / re-check"          -command cmgui::refresh    -accelerator "F5"
    $mf add command -label "Save module"                -command cmgui::saveModule -accelerator "Ctrl+S"
    $mf add separator
    $mf add command -label "Quit" -command cmgui::quit
    bind . <Control-o> cmgui::browseRoot
    bind . <F5>        cmgui::refresh
    bind . <Control-s> {cmgui::saveModule ; break}
    wm protocol . WM_DELETE_WINDOW cmgui::quit

    # toolbar
    set tb [ttk::frame .tb -padding 6]
    pack $tb -side top -fill x
    ttk::label  $tb.rl -text "Repo:"
    ttk::entry  $tb.re -textvariable ::cmgui::S(root) -width 48
    ttk::button $tb.rb -text "Browse\u2026" -command cmgui::browseRoot
    ttk::label  $tb.il -text "  Interp:"
    ttk::entry  $tb.ie -textvariable ::cmgui::S(interp) -width 14
    ttk::button $tb.go -text "Re-check" -command cmgui::refresh
    ttk::label  $tb.fl -text "   Filter:"
    set W(filter) [ttk::entry $tb.fe -width 22]
    bind $W(filter) <KeyRelease> {cmgui::fillTable}
    pack $tb.rl $tb.re $tb.rb $tb.il $tb.ie $tb.go $tb.fl $W(filter) -side left
    bind $tb.re <Return> cmgui::refresh

    # main paned: left table, right notebook
    set pw [ttk::panedwindow .pw -orient horizontal]
    pack $pw -side top -fill both -expand 1 -padx 6 -pady {0 6}

    # left: module table
    set lf [ttk::frame $pw.l]
    set cols {package version category test doc man}
    set tv [ttk::treeview $lf.tv -columns $cols -show headings -selectmode browse]
    foreach {c w} {package 230 version 70 category 200 test 46 doc 44 man 46} {
        $tv heading $c -text [string totitle $c] -command [list cmgui::onHeading $c]
        set anchor [expr {$c in {test doc man} ? "center" : "w"}]
        $tv column $c -width $w -anchor $anchor -stretch [expr {$c eq "category"}]
    }
    $tv tag configure lack -foreground "#b00020"
    set vsb [ttk::scrollbar $lf.vsb -orient vertical   -command [list $tv yview]]
    set hsb [ttk::scrollbar $lf.hsb -orient horizontal -command [list $tv xview]]
    $tv configure -yscrollcommand [list $vsb set] -xscrollcommand [list $hsb set]
    grid $tv $vsb -sticky nsew
    grid $hsb -sticky ew
    grid rowconfigure $lf 0 -weight 1
    grid columnconfigure $lf 0 -weight 1
    bind $tv <<TreeviewSelect>> cmgui::onSelect
    set W(tree) $tv
    $pw add $lf -weight 1

    # right: notebook (Report | Editor)
    set nb [ttk::notebook $pw.nb]
    set W(nb) $nb

    set rt [ttk::frame $nb.report]
    set rep [text $rt.t -wrap none -font TkFixedFont -undo 0]
    set rvs [ttk::scrollbar $rt.vs -orient vertical   -command [list $rep yview]]
    set rhs [ttk::scrollbar $rt.hs -orient horizontal -command [list $rep xview]]
    $rep configure -yscrollcommand [list $rvs set] -xscrollcommand [list $rhs set] -state disabled
    grid $rep $rvs -sticky nsew
    grid $rhs -sticky ew
    grid rowconfigure $rt 0 -weight 1 ; grid columnconfigure $rt 0 -weight 1
    set W(report) $rep
    $nb add $rt -text "Report"

    set et [ttk::frame $nb.edit]
    set W(edittab) $et
    set info [ttk::label $et.info -text "(no module selected)" -padding {2 4} -justify left -anchor w]
    set ebar [ttk::frame $et.bar]
    ttk::button $ebar.save -text "Save (Ctrl+S)" -command cmgui::saveModule
    pack $ebar.save -side left
    set edit [text $et.t -wrap none -undo 1 -font TkFixedFont]
    set evs [ttk::scrollbar $et.vs -orient vertical   -command [list $edit yview]]
    set ehs [ttk::scrollbar $et.hs -orient horizontal -command [list $edit xview]]
    $edit configure -yscrollcommand [list $evs set] -xscrollcommand [list $ehs set]
    grid $info -row 0 -column 0 -columnspan 2 -sticky ew
    grid $ebar -row 1 -column 0 -columnspan 2 -sticky ew -pady {0 4}
    grid $edit $evs -sticky nsew
    grid $ehs -sticky ew
    grid rowconfigure $et 2 -weight 1 ; grid columnconfigure $et 0 -weight 1
    bind $edit <<Modified>> cmgui::onModified
    set W(edit) $edit
    set W(info) $info
    $nb add $et -text "Editor"

    $pw add $nb -weight 2

    # status bar
    set W(status) [ttk::label .status -anchor w -relief sunken -padding {6 3}]
    pack .status -side bottom -fill x
    cmgui::setStatus "Ready. Pick a repository root containing tools/check-modules.tcl."
}

proc cmgui::quit {} {
    if {[cmgui::maybeDiscard]} { destroy . }
}

# ------------------------------------------------------------------------- main

proc cmgui::main {argv} {
    variable S
    if {[llength $argv] >= 1} { set S(root) [file normalize [lindex $argv 0]] }
    if {$S(root) eq ""} { set S(root) [pwd] }
    cmgui::buildUI
    if {[cmgui::looksLikeRepo $S(root)]} {
        cmgui::refresh
    } else {
        cmgui::setStatus "No check-modules.tcl under $S(root) \u2014 use File \u25b8 Open repository root."
    }
}

if {[info exists ::argv0]
    && [string equal [file tail [file rootname $::argv0]] "check-modules-gui"]} {
    cmgui::main $::argv
}
