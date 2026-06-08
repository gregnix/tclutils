#!/usr/bin/env wish
# tupngfont-editor -- visual editor for the 6x8 bitmap glyphs used by
# tclutils::tupngdraw (font6x8 / font6x8ext).
#
# A glyph = 8 row bitmasks (top..bottom). In each row, bit 5 is the LEFTMOST
# column and bit 0 the rightmost (6 columns) -- exactly the encoding that
# tupngdraw::_glyph reads from font6x8 / font6x8ext.
#
# Features:
#   * 6x8 grid editor (click toggles, drag paints)
#   * invert / flip H / flip V / shift, undo/redo (Ctrl+Z / Ctrl+Y)
#   * live preview at x1 / x2 / x4 / x8
#   * a glyph "collection" (code -> glyph) with a selectable list
#   * import existing glyphs from a .tcl/.tm file (font6x8 list, lset patches,
#     font6x8ext array)
#   * batch export: ASCII (32..126) as lset font6x8 patches, the rest as a
#     font6x8ext block  (note: ext is only consulted for codes outside 32..126,
#     so ASCII glyphs MUST be patched in the font6x8 list -- handled here)
#
# Standalone: needs only Tk (the preview reproduces tupngdraw's pixel layout).

package require Tk

namespace eval ::gfont {
    variable W 6          ;# columns
    variable H 8          ;# rows
    variable CS 30        ;# editor cell size in px
    variable px           ;# px(r,c) -> 0|1
    variable rectId       ;# rectId(r,c) -> canvas item
    variable cp ""        ;# character being edited
    variable paintVal 0   ;# value applied while dragging
    variable coll {}      ;# dict: code -> {8 row values}
    variable listCodes {} ;# codes in listbox order
    variable undo {}      ;# undo stack of glyph snapshots
    variable redo {}      ;# redo stack
    variable mapCols 12   ;# columns in the ASCII map window
    variable filter ""    ;# collection list filter
    variable curR 0       ;# keyboard cursor row
    variable curC 0       ;# keyboard cursor column
}

# ---- model -----------------------------------------------------------------

proc ::gfont::clearModel {} {
    variable px; variable W; variable H
    for {set r 0} {$r < $H} {incr r} {
        for {set c 0} {$c < $W} {incr c} { set px($r,$c) 0 }
    }
}

# encode current grid to 8 row values (bit5 = leftmost column)
proc ::gfont::glyphRows {} {
    variable px; variable W; variable H
    set rows {}
    for {set r 0} {$r < $H} {incr r} {
        set v 0
        for {set c 0} {$c < $W} {incr c} {
            if {$px($r,$c)} { set v [expr {$v | (1 << ($W - 1 - $c))}] }
        }
        lappend rows $v
    }
    return $rows
}

proc ::gfont::validRows {rows} {
    variable W; variable H
    if {[llength $rows] != $H} { return 0 }
    set max [expr {(1 << $W) - 1}]
    foreach v $rows {
        if {![string is integer -strict $v] || $v < 0 || $v > $max} { return 0 }
    }
    return 1
}

# low-level: set grid from a (valid) row list; does NOT push undo
proc ::gfont::applyRows {rows} {
    variable px; variable W; variable H
    for {set r 0} {$r < $H} {incr r} {
        set v [lindex $rows $r]
        for {set c 0} {$c < $W} {incr c} {
            set px($r,$c) [expr {($v >> ($W - 1 - $c)) & 1}]
        }
    }
    redrawGrid; refresh
}

# user-facing load (validates, records undo)
proc ::gfont::setFromRows {rows {quiet 0}} {
    if {![validRows $rows]} {
        if {!$quiet} {
            tk_messageBox -icon error -title "Load" \
                -message "Expected 8 row values in range, got: $rows"
        }
        return 0
    }
    pushUndo
    applyRows $rows
    return 1
}

# ---- undo / redo -----------------------------------------------------------

proc ::gfont::pushUndo {} {
    variable undo; variable redo
    lappend undo [glyphRows]
    if {[llength $undo] > 200} { set undo [lrange $undo end-200 end] }
    set redo {}
}

proc ::gfont::undo {} {
    variable undo; variable redo
    if {![llength $undo]} { status "Nothing to undo"; return }
    lappend redo [glyphRows]
    set rows [lindex $undo end]
    set undo [lrange $undo 0 end-1]
    applyRows $rows
    status "Undo"
}

proc ::gfont::redo {} {
    variable undo; variable redo
    if {![llength $redo]} { status "Nothing to redo"; return }
    lappend undo [glyphRows]
    set rows [lindex $redo end]
    set redo [lrange $redo 0 end-1]
    applyRows $rows
    status "Redo"
}

# ---- editor grid -----------------------------------------------------------

proc ::gfont::buildGrid {parent} {
    variable W; variable H; variable CS; variable rectId
    set cv $parent.cv
    canvas $cv -width [expr {$W * $CS + 1}] -height [expr {$H * $CS + 1}] \
        -bg white -highlightthickness 0
    grid $cv -row 0 -column 0
    for {set r 0} {$r < $H} {incr r} {
        for {set c 0} {$c < $W} {incr c} {
            set x0 [expr {$c * $CS + 1}]; set y0 [expr {$r * $CS + 1}]
            set rectId($r,$c) [$cv create rectangle $x0 $y0 \
                [expr {$x0 + $CS - 1}] [expr {$y0 + $CS - 1}] \
                -fill white -outline "#cccccc"]
        }
    }
    bind $cv <Button-1>  [list ::gfont::onPress %x %y]
    bind $cv <B1-Motion> [list ::gfont::onDrag %x %y]
    bind $cv <Button-3>  [list ::gfont::onErase %x %y 1]
    bind $cv <B3-Motion> [list ::gfont::onErase %x %y 0]
    $cv configure -takefocus 1
    bind $cv <Up>    {::gfont::moveCursor -1 0}
    bind $cv <Down>  {::gfont::moveCursor 1 0}
    bind $cv <Left>  {::gfont::moveCursor 0 -1}
    bind $cv <Right> {::gfont::moveCursor 0 1}
    bind $cv <space>  {::gfont::cursorToggle}
    bind $cv <Key-0>  {::gfont::cursorSet 0}
    bind $cv <Key-1>  {::gfont::cursorSet 1}
    drawCursor
    return $cv
}

proc ::gfont::xyToCell {x y} {
    variable W; variable H; variable CS
    set c [expr {int($x / $CS)}]; set r [expr {int($y / $CS)}]
    if {$r < 0 || $r >= $H || $c < 0 || $c >= $W} { return {} }
    return [list $r $c]
}

proc ::gfont::onPress {x y} {
    variable px; variable paintVal; variable curR; variable curC
    set rc [xyToCell $x $y]; if {$rc eq ""} return
    lassign $rc r c
    pushUndo
    set px($r,$c) [expr {!$px($r,$c)}]
    set paintVal $px($r,$c)
    set curR $r; set curC $c
    focus .top.ed.cv
    drawCell $r $c; drawCursor; refresh
}

proc ::gfont::onDrag {x y} {
    variable px; variable paintVal
    set rc [xyToCell $x $y]; if {$rc eq ""} return
    lassign $rc r c
    if {$px($r,$c) != $paintVal} { set px($r,$c) $paintVal; drawCell $r $c; refresh }
}

# right button erases (sets 0); press records one undo step for the stroke
proc ::gfont::onErase {x y press} {
    variable px
    set rc [xyToCell $x $y]; if {$rc eq ""} return
    lassign $rc r c
    if {$press} { pushUndo }
    if {$px($r,$c) != 0} { set px($r,$c) 0; drawCell $r $c; refresh }
}

proc ::gfont::drawCell {r c} {
    variable px; variable rectId
    .top.ed.cv itemconfigure $rectId($r,$c) \
        -fill [expr {$px($r,$c) ? "black" : "white"}]
}

proc ::gfont::redrawGrid {} {
    variable W; variable H
    for {set r 0} {$r < $H} {incr r} {
        for {set c 0} {$c < $W} {incr c} { drawCell $r $c }
    }
}

# change editor cell size (zoom) by rebuilding the grid canvas
proc ::gfont::setZoom {newCS} {
    variable CS
    if {![string is integer -strict $newCS] || $newCS < 8} return
    set CS $newCS
    catch {destroy .top.ed.cv}
    buildGrid .top.ed
    redrawGrid
}

# ---- preview ---------------------------------------------------------------

proc ::gfont::drawPreview {} {
    variable W; variable H
    set cv .top.ed.prev.cv
    $cv delete all
    set rows [glyphRows]
    set x 12
    foreach s {1 2 4 8} {
        set top 14
        $cv create rectangle [expr {$x-2}] [expr {$top-2}] \
            [expr {$x + $W*$s + 1}] [expr {$top + $H*$s + 1}] -outline "#dddddd"
        for {set r 0} {$r < $H} {incr r} {
            set v [lindex $rows $r]
            for {set c 0} {$c < $W} {incr c} {
                if {($v >> ($W - 1 - $c)) & 1} {
                    set x0 [expr {$x + $c*$s}]; set y0 [expr {$top + $r*$s}]
                    $cv create rectangle $x0 $y0 [expr {$x0+$s}] [expr {$y0+$s}] \
                        -fill black -outline ""
                }
            }
        }
        $cv create text [expr {$x + $W*$s/2.0}] [expr {$top + $H*$s + 8}] \
            -text "x$s" -font {TkDefaultFont 7} -fill "#888888"
        set x [expr {$x + $W*$s + 18}]
    }
}

# ---- character helpers -----------------------------------------------------

proc ::gfont::currentCode {} {
    variable cp
    set ch [string index $cp 0]
    if {$ch eq ""} { return "" }
    return [scan $ch %c]
}

proc ::gfont::charRepr {code} {
    if {$code >= 32 && $code <= 126} { return [format %c $code] }
    return "U+[format %04X $code]"
}

proc ::gfont::refresh {} {
    drawPreview
    set rows [glyphRows]
    .top.ed.cur.e configure -state normal
    .top.ed.cur.e delete 0 end
    .top.ed.cur.e insert end "{$rows}"
    .top.ed.cur.e configure -state readonly
    if {[winfo exists .top.ed.hex.e]} {
        .top.ed.hex.e configure -state normal
        .top.ed.hex.e delete 0 end
        .top.ed.hex.e insert end [hexString]
        .top.ed.hex.e configure -state readonly
    }
}

proc ::gfont::hexString {} {
    set hx {}
    foreach v [glyphRows] { lappend hx [format 0x%02X $v] }
    return "{[join $hx { }]}"
}

proc ::gfont::copyHex {} {
    clipboard clear; clipboard append [hexString]
    status "Copied hex: [hexString]"
}

proc ::gfont::copyCurrent {} {
    set s "{[glyphRows]}"
    clipboard clear; clipboard append $s
    status "Copied glyph: $s"
}

proc ::gfont::loadChar {} {
    variable coll
    set code [currentCode]
    if {$code eq ""} { status "Enter a character first"; return }
    if {![dict exists $coll $code]} {
        status "Code $code ([charRepr $code]) not in collection - import a font first"
        return
    }
    setFromRows [dict get $coll $code]
    status "Loaded code $code ([charRepr $code]) from collection"
}

# ---- collection ------------------------------------------------------------

proc ::gfont::collRefreshList {{selectCode ""}} {
    variable coll; variable listCodes; variable filter
    set lb .top.col.lbf.lb
    $lb delete 0 end
    set listCodes {}
    set f [string tolower [string trim $filter]]
    foreach code [lsort -integer [dict keys $coll]] {
        if {$f ne "" && [string first $f [string tolower "$code [charRepr $code]"]] < 0} continue
        lappend listCodes $code
        $lb insert end [format "%4d  %-7s {%s}" $code [charRepr $code] [dict get $coll $code]]
    }
    if {$selectCode ne ""} {
        set idx [lsearch -exact $listCodes $selectCode]
        if {$idx >= 0} { $lb selection clear 0 end; $lb selection set $idx; $lb see $idx }
    }
    set total [dict size $coll]
    if {$f ne ""} {
        .top.col.cnt configure -text "[llength $listCodes] of $total glyph(s) shown"
    } else {
        .top.col.cnt configure -text "$total glyph(s)"
    }
}

proc ::gfont::collAddUpdate {} {
    variable coll
    set code [currentCode]
    if {$code eq ""} {
        tk_messageBox -icon info -title "Add/Update" \
            -message "Enter a character first (field 'Character')."
        return
    }
    set existed [dict exists $coll $code]
    dict set coll $code [glyphRows]
    collRefreshList $code
    status "[expr {$existed ? {Updated} : {Added}}] code $code ([charRepr $code])"
}

proc ::gfont::collSelectedCode {} {
    variable listCodes
    set sel [.top.col.lbf.lb curselection]
    if {$sel eq ""} { return "" }
    return [lindex $listCodes [lindex $sel 0]]
}

proc ::gfont::collLoad {} {
    variable coll; variable cp
    set code [collSelectedCode]
    if {$code eq ""} { return }
    setFromRows [dict get $coll $code]
    if {$code >= 32 && $code <= 126} { set cp [format %c $code] } else { set cp "" }
    refresh
    status "Loaded code $code ([charRepr $code]) into the editor"
}

proc ::gfont::collRemove {} {
    variable coll
    set code [collSelectedCode]
    if {$code eq ""} { return }
    dict unset coll $code
    collRefreshList
    status "Removed code $code"
}

proc ::gfont::collNew {} {
    variable cp
    pushUndo; clearModel; redrawGrid; set cp ""; refresh
    status "New glyph"
}

# split export: ASCII -> lset font6x8 patches, rest -> font6x8ext block
proc ::gfont::collExportText {} {
    variable coll
    set ascii {}; set ext {}
    foreach code [lsort -integer [dict keys $coll]] {
        if {$code >= 32 && $code <= 126} { lappend ascii $code } else { lappend ext $code }
    }
    set out ""
    if {[llength $ascii]} {
        append out "# ASCII overrides - patch the existing font6x8 list in place:\n"
        foreach code $ascii {
            append out [format "lset ::tclutils::tupngdraw::font6x8 %-3d {%s}\n" \
                [expr {$code - 32}] [dict get $coll $code]]
        }
        append out "\n"
    }
    if {[llength $ext]} {
        append out "# non-ASCII glyphs:\n"
        append out "array set ::tclutils::tupngdraw::font6x8ext \{\n"
        foreach code $ext {
            append out [format "    %-5d {%s}\n" $code [dict get $coll $code]]
        }
        append out "\}\n"
    }
    if {$out eq ""} { set out "# (collection is empty)\n" }
    return $out
}

proc ::gfont::collShowExport {} {
    set t .top.col.exp.txt
    $t configure -state normal
    $t delete 1.0 end
    $t insert end [collExportText]
    $t configure -state disabled
}

proc ::gfont::collCopyAll {} {
    clipboard clear; clipboard append [collExportText]
    status "Copied export ([dict size $::gfont::coll] glyphs)"
}

proc ::gfont::collSaveAll {} {
    set f [tk_getSaveFile -defaultextension .tcl \
        -filetypes {{Tcl {.tcl}} {All *}} -initialfile "font6x8-glyphs.tcl"]
    if {$f eq ""} return
    set fid [open $f w]; fconfigure $fid -encoding utf-8
    puts $fid "# generated by tupngfont-editor -- tupngdraw glyphs (6x8, bit5=leftmost)"
    puts -nonewline $fid [collExportText]
    close $fid
    status "Saved collection: $f"
}

# ---- import ----------------------------------------------------------------

proc ::gfont::extractBalanced {txt fromIdx} {
    set n [string length $txt]
    set open [string first "\{" $txt $fromIdx]
    if {$open < 0} { return "" }
    set depth 0; set begin -1
    for {set i $open} {$i < $n} {incr i} {
        set ch [string index $txt $i]
        if {$ch eq "\{"} { incr depth; if {$depth == 1} { set begin [expr {$i+1}] } } \
        elseif {$ch eq "\}"} { incr depth -1; if {$depth == 0} { return [string range $txt $begin [expr {$i-1}]] } }
    }
    return ""
}

proc ::gfont::stripComments {inner} {
    set out ""
    foreach line [split $inner \n] {
        set l [string trim $line]
        if {$l eq "" || [string index $l 0] eq "#"} continue
        append out $line "\n"
    }
    return $out
}

proc ::gfont::parseFontFile {path} {
    set fid [open $path r]; fconfigure $fid -encoding utf-8
    set txt [read $fid]; close $fid
    set result {}

    # font6x8 list (ASCII 32..126)
    if {[regexp -indices {font6x8\s*\{} $txt m]} {
        set inner [stripComments [extractBalanced $txt [lindex $m 0]]]
        if {![catch {llength $inner}]} {
            set i 0
            foreach g $inner { if {[validRows $g]} { dict set result [expr {32 + $i}] $g }; incr i }
        }
    }
    # lset font6x8 IDX {rows}
    foreach {full idx rows} [regexp -all -inline {lset\s+\S*font6x8\s+(\d+)\s+(\{[^{}]*\})} $txt] {
        set rl [string trim $rows "{} "]
        if {[validRows $rl]} { dict set result [expr {32 + $idx}] $rl }
    }
    # array set ...font6x8ext { code {rows} ... }
    foreach idx [regexp -all -indices -inline {font6x8ext\s*\{} $txt] {
        set inner [stripComments [extractBalanced $txt [lindex $idx 0]]]
        if {![catch {llength $inner} nlen] && $nlen % 2 == 0} {
            foreach {code rows} $inner {
                if {[string is integer -strict $code] && [validRows $rows]} {
                    dict set result $code $rows
                }
            }
        }
    }
    # font6x8ext(CODE) {rows}
    foreach {full code rows} [regexp -all -inline {font6x8ext\((\d+)\)\s*(\{[^{}]*\})} $txt] {
        set rl [string trim $rows "{} "]
        if {[validRows $rl]} { dict set result $code $rl }
    }
    return $result
}

proc ::gfont::importDialog {} {
    variable coll
    set f [tk_getOpenFile -filetypes {{Tcl/Module {.tcl .tm}} {All *}}]
    if {$f eq ""} return
    if {[catch {parseFontFile $f} got]} {
        tk_messageBox -icon error -title "Import" -message "Parse failed:\n$got"
        return
    }
    if {[dict size $got] == 0} {
        tk_messageBox -icon warning -title "Import" \
            -message "No font6x8 / font6x8ext glyphs found in:\n$f"
        return
    }
    set new 0; set upd 0
    dict for {code rows} $got {
        if {[dict exists $coll $code]} { incr upd } else { incr new }
        dict set coll $code $rows
    }
    collRefreshList
    status "Imported [file tail $f]: $new new, $upd updated ([dict size $got] total)"
}

# ---- transforms ------------------------------------------------------------

proc ::gfont::invert {} {
    variable px; variable W; variable H
    pushUndo
    for {set r 0} {$r < $H} {incr r} {
        for {set c 0} {$c < $W} {incr c} { set px($r,$c) [expr {!$px($r,$c)}] }
    }
    redrawGrid; refresh
}

proc ::gfont::flipH {} {
    variable px; variable W; variable H
    pushUndo
    array set old [array get px]
    for {set r 0} {$r < $H} {incr r} {
        for {set c 0} {$c < $W} {incr c} { set px($r,$c) $old($r,[expr {$W-1-$c}]) }
    }
    redrawGrid; refresh
}

proc ::gfont::flipV {} {
    variable px; variable W; variable H
    pushUndo
    array set old [array get px]
    for {set r 0} {$r < $H} {incr r} {
        for {set c 0} {$c < $W} {incr c} { set px($r,$c) $old([expr {$H-1-$r}],$c) }
    }
    redrawGrid; refresh
}

# 180 deg (= flip H + flip V); 90/270 are omitted because a 6x8 cell is not
# square -- a quarter turn would need an 8x6 grid and cannot be stored as 6x8.
proc ::gfont::rotate180 {} {
    variable px; variable W; variable H
    pushUndo
    array set old [array get px]
    for {set r 0} {$r < $H} {incr r} {
        for {set c 0} {$c < $W} {incr c} {
            set px($r,$c) $old([expr {$H-1-$r}],[expr {$W-1-$c}])
        }
    }
    redrawGrid; refresh
}

proc ::gfont::shift {dir} {
    variable px; variable W; variable H
    pushUndo
    array set old [array get px]
    for {set r 0} {$r < $H} {incr r} {
        for {set c 0} {$c < $W} {incr c} {
            switch -- $dir {
                up    { set sr [expr {$r+1}]; set sc $c }
                down  { set sr [expr {$r-1}]; set sc $c }
                left  { set sr $r; set sc [expr {$c+1}] }
                right { set sr $r; set sc [expr {$c-1}] }
            }
            if {$sr >= 0 && $sr < $H && $sc >= 0 && $sc < $W} {
                set px($r,$c) $old($sr,$sc)
            } else { set px($r,$c) 0 }
        }
    }
    redrawGrid; refresh
}

proc ::gfont::clearAll {} { pushUndo; clearModel; redrawGrid; refresh }

proc ::gfont::status {msg} { .bottom.status configure -text $msg }

# ---- shared glyph drawing (used by map + test) -----------------------------

proc ::gfont::drawGlyphOn {cv x y rows scale {col black}} {
    variable W; variable H
    for {set r 0} {$r < $H} {incr r} {
        set v [lindex $rows $r]
        for {set c 0} {$c < $W} {incr c} {
            if {($v >> ($W - 1 - $c)) & 1} {
                set x0 [expr {$x + $c*$scale}]; set y0 [expr {$y + $r*$scale}]
                $cv create rectangle $x0 $y0 [expr {$x0+$scale}] [expr {$y0+$scale}] \
                    -fill $col -outline ""
            }
        }
    }
}

# ---- paste -----------------------------------------------------------------

proc ::gfont::pasteGlyph {} {
    if {[catch {clipboard get} s]} { status "Clipboard is empty"; return }
    set s [string trim [string trim $s] "{}"]
    if {[setFromRows $s]} { status "Pasted glyph" }
}

# ---- ASCII map (32..126) ---------------------------------------------------

proc ::gfont::asciiMap {} {
    variable coll
    set t .ascii
    catch {destroy $t}
    toplevel $t; wm title $t "ASCII map  32-126"
    variable mapCols
    if {![string is integer -strict $mapCols] || $mapCols < 6} { set mapCols 12 }
    set cols $mapCols; set cw 34; set ch 48
    set nrows [expr {int(ceil((126-32+1)/double($cols)))}]
    set cv $t.cv
    canvas $cv -width [expr {$cols*$cw+2}] -height [expr {$nrows*$ch+2}] \
        -bg white -highlightthickness 0
    pack $cv -padx 6 -pady 6
    set missing {}
    for {set code 32} {$code <= 126} {incr code} {
        set i [expr {$code-32}]
        set cx [expr {($i % $cols)*$cw + 1}]
        set cy [expr {($i / $cols)*$ch + 1}]
        set present [dict exists $coll $code]
        if {!$present} { lappend missing $code }
        $cv create rectangle $cx $cy [expr {$cx+$cw-1}] [expr {$cy+$ch-1}] \
            -fill [expr {$present ? "#e8f5e9" : "#f7f7f7"}] -outline "#dddddd"
        if {$present} {
            drawGlyphOn $cv [expr {$cx+13}] [expr {$cy+6}] [dict get $coll $code] 2
        }
        $cv create text [expr {$cx+3}] [expr {$cy+7}] -text $code \
            -font {TkDefaultFont 6} -fill "#999999" -anchor w
        $cv create text [expr {$cx+$cw/2}] [expr {$cy+$ch-9}] -text [format %c $code] \
            -font {TkFixedFont 9}
    }
    bind $cv <Button-1> [list ::gfont::asciiMapClick %x %y $cols $cw $ch]
    ttk::frame $t.b -padding {6 0 6 6}
    pack $t.b -fill x
    set nMiss [llength $missing]
    if {$nMiss > 24} {
        set missTxt "[lrange $missing 0 23] +[expr {$nMiss-24}] more"
    } else {
        set missTxt $missing
    }
    ttk::label $t.b.info -justify left -wraplength [expr {$cols*$cw - 150}] \
        -text "[expr {95-$nMiss}]/95 present.   Missing ($nMiss): $missTxt"
    ttk::button $t.b.rf -text "Refresh" -command ::gfont::asciiMap
    ttk::label $t.b.cl -text "Cols:"
    ttk::spinbox $t.b.cols -from 6 -to 24 -width 3 \
        -textvariable ::gfont::mapCols -command ::gfont::asciiMap
    bind $t.b.cols <Return> ::gfont::asciiMap
    pack $t.b.info -side left
    pack $t.b.rf -side right
    pack $t.b.cols -side right -padx {2 6}
    pack $t.b.cl -side right
}

proc ::gfont::asciiMapClick {x y cols cw ch} {
    variable coll; variable cp
    set col [expr {int($x/$cw)}]; set row [expr {int($y/$ch)}]
    set code [expr {32 + $row*$cols + $col}]
    if {$code < 32 || $code > 126} return
    set cp [format %c $code]
    if {[dict exists $coll $code]} {
        setFromRows [dict get $coll $code]
        status "Loaded code $code ([charRepr $code]) from map"
    } else {
        clearAll
        status "Code $code ([charRepr $code]) is missing - drawing new"
    }
    refresh
}

# ---- font test ("Hallo Welt") ----------------------------------------------

proc ::gfont::fontTest {} {
    set t .fonttest
    catch {destroy $t}
    toplevel $t; wm title $t "Font test"
    ttk::frame $t.top -padding 6; pack $t.top -fill x
    ttk::label $t.top.l -text "Text:"
    ttk::entry $t.top.e -width 40
    $t.top.e insert end "Hallo Welt"
    ttk::label $t.top.sl -text "Scale:"
    ttk::spinbox $t.top.sp -from 1 -to 12 -width 3 -command ::gfont::fontTestRender
    $t.top.sp set 4
    pack $t.top.l $t.top.e $t.top.sl $t.top.sp -side left -padx 3
    canvas $t.cv -width 600 -height 140 -bg white -highlightthickness 0
    pack $t.cv -padx 6 -pady 6 -fill both -expand 1
    ttk::label $t.note -foreground "#888888" -text \
        "Glyphs come from the collection (import a font first). Missing = empty box."
    pack $t.note -anchor w -padx 6 -pady {0 6}
    bind $t.top.e <KeyRelease> ::gfont::fontTestRender
    ::gfont::fontTestRender
}

proc ::gfont::fontTestRender {} {
    variable coll; variable W; variable H
    set t .fonttest
    if {![winfo exists $t]} return
    set cv $t.cv; $cv delete all
    set str [$t.top.e get]
    set sc [$t.top.sp get]
    if {![string is integer -strict $sc] || $sc < 1} { set sc 4 }
    set sp 1
    set x 10; set y 20
    foreach ch [split $str ""] {
        set code [scan $ch %c]
        if {[dict exists $coll $code]} {
            drawGlyphOn $cv $x $y [dict get $coll $code] $sc
        } else {
            $cv create rectangle $x $y [expr {$x+$W*$sc}] [expr {$y+$H*$sc}] -outline "#dddddd"
        }
        set x [expr {$x + ($W + $sp)*$sc}]
        if {$x > [expr {[winfo width $cv] - $W*$sc}]} { set x 10; incr y [expr {($H+2)*$sc}] }
    }
}

# ---- keyboard cursor -------------------------------------------------------

proc ::gfont::drawCursor {} {
    variable curR; variable curC; variable CS
    set cv .top.ed.cv
    if {![winfo exists $cv]} return
    $cv delete cursor
    set x0 [expr {$curC*$CS + 3}]; set y0 [expr {$curR*$CS + 3}]
    set x1 [expr {$curC*$CS + $CS - 3}]; set y1 [expr {$curR*$CS + $CS - 3}]
    $cv create rectangle $x0 $y0 $x1 $y1 -outline "#3b82f6" -width 2 -tags cursor
}

proc ::gfont::moveCursor {dr dc} {
    variable curR; variable curC; variable W; variable H
    set curR [expr {max(0, min($H-1, $curR+$dr))}]
    set curC [expr {max(0, min($W-1, $curC+$dc))}]
    drawCursor
}

proc ::gfont::cursorToggle {} {
    variable px; variable curR; variable curC
    pushUndo
    set px($curR,$curC) [expr {!$px($curR,$curC)}]
    drawCell $curR $curC; drawCursor; refresh
}

proc ::gfont::cursorSet {v} {
    variable px; variable curR; variable curC
    pushUndo
    set px($curR,$curC) $v
    drawCell $curR $curC; drawCursor; refresh
}

# ---- PNG / GIF import (image -> 6x8 glyph) ---------------------------------

# luminance + alpha of one source pixel (alpha 255 if not available)
proc ::gfont::_pixelLA {img x y} {
    if {[catch {$img get $x $y -withalpha} v]} {
        lassign [$img get $x $y] R G B; set A 255
    } else {
        lassign $v R G B A
        if {$A eq ""} { set A 255 }
    }
    return [list [expr {0.299*$R + 0.587*$G + 0.114*$B}] $A]
}

# decide on/off for one grid cell by block-averaging the mapped source region
proc ::gfont::_sampleOn {img iw ih r c} {
    variable W; variable H
    set x0 [expr {int(double($c)/$W*$iw)}];   set x1 [expr {int(double($c+1)/$W*$iw)}]
    set y0 [expr {int(double($r)/$H*$ih)}];   set y1 [expr {int(double($r+1)/$H*$ih)}]
    if {$x1 <= $x0} { set x1 [expr {$x0+1}] }
    if {$y1 <= $y0} { set y1 [expr {$y0+1}] }
    set sxN [expr {min(3, $x1-$x0)}]; set syN [expr {min(3, $y1-$y0)}]
    set sumL 0.0; set sumA 0.0; set n 0
    for {set i 0} {$i < $syN} {incr i} {
        set yy [expr {$y0 + ($y1-$y0)*$i/$syN}]
        for {set j 0} {$j < $sxN} {incr j} {
            set xx [expr {$x0 + ($x1-$x0)*$j/$sxN}]
            lassign [_pixelLA $img $xx $yy] L A
            set sumL [expr {$sumL+$L}]; set sumA [expr {$sumA+$A}]; incr n
        }
    }
    if {$n == 0} { return 0 }
    if {[expr {$sumA/$n}] < 128} { return 0 }          ;# mostly transparent -> off
    return [expr {[expr {$sumL/$n}] < 128 ? 1 : 0}]    ;# dark -> on
}

# convert an existing photo image into the editor grid; returns # of on-pixels
proc ::gfont::importPhoto {img} {
    variable px; variable W; variable H
    set iw [image width $img]; set ih [image height $img]
    if {$iw < 1 || $ih < 1} { return 0 }
    pushUndo
    set on 0
    for {set r 0} {$r < $H} {incr r} {
        for {set c 0} {$c < $W} {incr c} {
            set v [_sampleOn $img $iw $ih $r $c]
            set px($r,$c) $v; incr on $v
        }
    }
    redrawGrid; drawCursor; refresh
    return $on
}

proc ::gfont::importPNG {} {
    set f [tk_getOpenFile -filetypes {{PNG/GIF {.png .gif}} {All *}}]
    if {$f eq ""} return
    if {[catch {image create photo gfImportImg -file $f} e]} {
        tk_messageBox -icon error -title "Image import" -message "Cannot load image:\n$e"
        return
    }
    set iw [image width gfImportImg]; set ih [image height gfImportImg]
    set on [importPhoto gfImportImg]
    image delete gfImportImg
    status "Imported [file tail $f] ($iw x $ih -> 6x8, $on px). Use Invert if reversed."
}

# ---- UI --------------------------------------------------------------------

proc ::gfont::buildUI {} {
    wm title . "tupngfont-editor  -  6x8 bitmap glyphs (tupngdraw)"

    ttk::frame .top -padding 8
    pack .top -fill both -expand 1

    # --- left: editor -------------------------------------------------------
    ttk::labelframe .top.ed -text "Glyph 6x8  (click toggles, drag paints)" -padding 6
    pack .top.ed -side left -anchor n -padx {0 10}
    ::gfont::buildGrid .top.ed

    ttk::frame .top.ed.tools
    grid .top.ed.tools -row 1 -column 0 -pady {8 0}
    ttk::button .top.ed.tools.clr -text "Clear"  -width 6 -command ::gfont::clearAll
    ttk::button .top.ed.tools.inv -text "Invert" -width 6 -command ::gfont::invert
    ttk::button .top.ed.tools.fh  -text "Flip H" -width 6 -command ::gfont::flipH
    ttk::button .top.ed.tools.fv  -text "Flip V" -width 6 -command ::gfont::flipV
    ttk::button .top.ed.tools.rot -text "Rot 180" -width 7 -command ::gfont::rotate180
    ttk::button .top.ed.tools.u -text "↑" -width 3 -command {::gfont::shift up}
    ttk::button .top.ed.tools.d -text "↓" -width 3 -command {::gfont::shift down}
    ttk::button .top.ed.tools.l -text "←" -width 3 -command {::gfont::shift left}
    ttk::button .top.ed.tools.r -text "→" -width 3 -command {::gfont::shift right}
    ttk::button .top.ed.tools.uz -text "Undo" -width 6 -command ::gfont::undo
    ttk::button .top.ed.tools.rz -text "Redo" -width 6 -command ::gfont::redo
    grid .top.ed.tools.clr .top.ed.tools.inv .top.ed.tools.fh .top.ed.tools.fv .top.ed.tools.rot \
         -row 0 -padx 1 -pady 1 -sticky w
    grid .top.ed.tools.u .top.ed.tools.d .top.ed.tools.l .top.ed.tools.r \
         .top.ed.tools.uz .top.ed.tools.rz -row 1 -padx 1 -pady 1 -sticky w

    ttk::frame .top.ed.chrow
    grid .top.ed.chrow -row 2 -column 0 -pady {8 0} -sticky w
    ttk::label  .top.ed.chrow.l -text "Character:"
    ttk::entry  .top.ed.chrow.e -width 4 -textvariable ::gfont::cp
    ttk::button .top.ed.chrow.b -text "Load char" -command ::gfont::loadChar
    ttk::label  .top.ed.chrow.zl -text "   Zoom:"
    ttk::combobox .top.ed.chrow.z -width 3 -state readonly -values {20 30 40 60}
    .top.ed.chrow.z set 30
    bind .top.ed.chrow.z <<ComboboxSelected>> {::gfont::setZoom [.top.ed.chrow.z get]}
    ttk::button .top.ed.chrow.png -text "Img→glyph…" -command ::gfont::importPNG
    pack .top.ed.chrow.l .top.ed.chrow.e .top.ed.chrow.b \
         .top.ed.chrow.zl .top.ed.chrow.z .top.ed.chrow.png -side left -padx 2
    bind .top.ed.chrow.e <KeyRelease> ::gfont::refresh

    ttk::labelframe .top.ed.prev -text "Preview (x1 / x2 / x4 / x8)" -padding 6
    grid .top.ed.prev -row 3 -column 0 -pady {8 0} -sticky we
    canvas .top.ed.prev.cv -width 280 -height 90 -bg white -highlightthickness 0
    pack .top.ed.prev.cv

    ttk::frame .top.ed.cur
    grid .top.ed.cur -row 4 -column 0 -pady {8 0} -sticky we
    ttk::entry .top.ed.cur.e -width 24 -font TkFixedFont -state readonly
    ttk::button .top.ed.cur.b -text "Copy glyph" -command ::gfont::copyCurrent
    ttk::button .top.ed.cur.p -text "Paste" -command ::gfont::pasteGlyph
    pack .top.ed.cur.e -side left -fill x -expand 1
    pack .top.ed.cur.b -side left -padx {4 0}
    pack .top.ed.cur.p -side left -padx {2 0}

    ttk::frame .top.ed.hex
    grid .top.ed.hex -row 5 -column 0 -pady {4 0} -sticky we
    ttk::entry .top.ed.hex.e -width 24 -font TkFixedFont -state readonly
    ttk::button .top.ed.hex.b -text "Copy hex" -command ::gfont::copyHex
    pack .top.ed.hex.e -side left -fill x -expand 1
    pack .top.ed.hex.b -side left -padx {4 0}

    # --- right: collection --------------------------------------------------
    ttk::labelframe .top.col -text "Glyph collection" -padding 6
    pack .top.col -side left -anchor n -fill both -expand 1

    ttk::frame .top.col.lbf
    grid .top.col.lbf -row 0 -column 0 -sticky nsew
    ttk::frame .top.col.lbf.f
    ttk::label .top.col.lbf.f.l -text "Filter:"
    ttk::entry .top.col.lbf.f.e -textvariable ::gfont::filter
    pack .top.col.lbf.f.l -side left
    pack .top.col.lbf.f.e -side left -fill x -expand 1
    bind .top.col.lbf.f.e <KeyRelease> ::gfont::collRefreshList
    listbox .top.col.lbf.lb -width 30 -height 14 -font TkFixedFont \
        -activestyle dotbox -yscrollcommand {.top.col.lbf.sb set}
    ttk::scrollbar .top.col.lbf.sb -orient vertical -command {.top.col.lbf.lb yview}
    grid .top.col.lbf.f  -row 0 -column 0 -columnspan 2 -sticky we -pady {0 2}
    grid .top.col.lbf.lb -row 1 -column 0 -sticky nsew
    grid .top.col.lbf.sb -row 1 -column 1 -sticky ns
    grid rowconfigure .top.col.lbf 1 -weight 1
    grid columnconfigure .top.col.lbf 0 -weight 1
    bind .top.col.lbf.lb <Double-1> ::gfont::collLoad
    bind .top.col.lbf.lb <Return>   ::gfont::collLoad

    ttk::label .top.col.cnt -text "0 glyph(s)" -foreground "#888888"
    grid .top.col.cnt -row 1 -column 0 -sticky w -pady {4 0}

    ttk::frame .top.col.btns
    grid .top.col.btns -row 2 -column 0 -sticky w -pady {6 0}
    ttk::button .top.col.btns.new -text "New"        -width 9  -command ::gfont::collNew
    ttk::button .top.col.btns.add -text "Add/Update" -width 11 -command ::gfont::collAddUpdate
    ttk::button .top.col.btns.ld  -text "Load →"     -width 9  -command ::gfont::collLoad
    ttk::button .top.col.btns.rm  -text "Remove"     -width 9  -command ::gfont::collRemove
    grid .top.col.btns.new .top.col.btns.add -padx 2 -pady 2 -sticky w
    grid .top.col.btns.ld  .top.col.btns.rm  -padx 2 -pady 2 -sticky w

    ttk::frame .top.col.io
    grid .top.col.io -row 3 -column 0 -sticky w -pady {6 0}
    ttk::button .top.col.io.imp  -text "Import…"     -width 11 -command ::gfont::importDialog
    ttk::button .top.col.io.exp  -text "Show export" -width 12 -command ::gfont::collShowExport
    ttk::button .top.col.io.map  -text "ASCII map…"  -width 11 -command ::gfont::asciiMap
    ttk::button .top.col.io.test -text "Font test…"  -width 12 -command ::gfont::fontTest
    grid .top.col.io.imp .top.col.io.exp  -row 0 -padx 2 -pady 1 -sticky w
    grid .top.col.io.map .top.col.io.test -row 1 -padx 2 -pady 1 -sticky w

    ttk::labelframe .top.col.exp -text "Export (ASCII as lset, rest as font6x8ext)" -padding 4
    grid .top.col.exp -row 4 -column 0 -sticky nsew -pady {6 0}
    text .top.col.exp.txt -width 40 -height 8 -wrap none -font TkFixedFont -state disabled
    pack .top.col.exp.txt -fill both -expand 1
    ttk::frame .top.col.exp.b
    pack .top.col.exp.b -anchor w -pady {4 0}
    ttk::button .top.col.exp.b.cp -text "Copy all"  -command ::gfont::collCopyAll
    ttk::button .top.col.exp.b.sv -text "Save all…" -command ::gfont::collSaveAll
    pack .top.col.exp.b.cp .top.col.exp.b.sv -side left -padx 2

    grid rowconfigure .top.col 0 -weight 1
    grid rowconfigure .top.col 4 -weight 1
    grid columnconfigure .top.col 0 -weight 1

    ttk::frame .bottom -padding {8 0 8 8}
    pack .bottom -fill x
    ttk::label .bottom.status -text \
        "Ready  (click grid then arrows move, Space/0/1 set, Ctrl+Z/Y undo/redo)" \
        -foreground "#555555"
    pack .bottom.status -anchor w

    # global shortcuts
    bind . <Control-z> {::gfont::undo}
    bind . <Control-y> {::gfont::redo}
    bind . <Control-Z> {::gfont::redo}
}

# ---- main ------------------------------------------------------------------

::gfont::clearModel
::gfont::buildUI
::gfont::redrawGrid
::gfont::refresh

# headless smoke-test hook
if {[info exists ::env(DEMO_NOLOOP)]} { update idletasks; exit 0 }
