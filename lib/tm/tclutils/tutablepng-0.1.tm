# tclutils::tutablepng -- render tabular data to a PNG table image, using the
# Description: render tabular data to a PNG table image via tclutils::tupngdraw (no Tk)
# Category: Graphics · raster/vector
# pure-Tcl drawing layer tclutils::tupngdraw (no Tk, no external packages).
#
# An "export adapter": data in -> a styled table image out (header row, column
# alignment, zebra striping, grid lines), suitable for thumbnails, reports and
# attachments.
#
#   package require tclutils::tutablepng
#   set rows {
#       {Name      Qty Price}
#       {Apples     12  3.40}
#       {Pears       4  2.10}
#   }
#   tclutils::tutablepng::write table.png $rows -header 1 -align {l r r} -zebra {245 245 248}
#
# rows is a list of rows; each row is a list of cell strings. Short rows are
# padded with empty cells. Returns/writes 8-bit RGBA PNG bytes.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tupngdraw 0.12

namespace eval ::tclutils {}
namespace eval ::tclutils::tutablepng {
    namespace export render write
    variable version 0.1
}

proc ::tclutils::tutablepng::_aligns {spec ncols} {
    if {[llength $spec] <= 1} {
        set a [expr {$spec eq "" ? "l" : [lindex $spec 0]}]
        if {$a ni {l c r}} {
            return -code error -errorcode {TCLUTILS TUTABLEPNG ALIGN} \
                "-align must be l|c|r (or a per-column list of them)"
        }
        return [lrepeat $ncols $a]
    }
    set out {}
    for {set c 0} {$c < $ncols} {incr c} {
        set a [expr {$c < [llength $spec] ? [lindex $spec $c] : [lindex $spec end]}]
        if {$a ni {l c r}} {
            return -code error -errorcode {TCLUTILS TUTABLEPNG ALIGN} \
                "-align entries must be l|c|r"
        }
        lappend out $a
    }
    return $out
}

# Render rows -> PNG bytes.
proc ::tclutils::tutablepng::render {rows args} {
    set o [::tclutils::common::parseOptions {
        -header 1 -align l -scale 1 -padding 6 -spacing 1
        -background white -gridcolor {180 180 185} -textcolor {25 25 25}
        -headerbg {230 230 238} -headertext {0 0 0}
        -zebra {} -border 1
    } {*}$args]
    if {[llength $rows] == 0} {
        return -code error -errorcode {TCLUTILS TUTABLEPNG EMPTY} "no rows to render"
    }
    ::tclutils::common::ensureBoolean [dict get $o -header] -header
    ::tclutils::common::ensureBoolean [dict get $o -border] -border
    set scale [::tclutils::common::ensurePositiveInteger [dict get $o -scale] -scale]
    set pad   [dict get $o -padding]
    set sp    [dict get $o -spacing]
    set header [dict get $o -header]

    set ncols 0
    foreach r $rows { if {[llength $r] > $ncols} { set ncols [llength $r] } }
    if {$ncols == 0} {
        return -code error -errorcode {TCLUTILS TUTABLEPNG EMPTY} "rows have no columns"
    }
    set aligns [_aligns [dict get $o -align] $ncols]

    # per-char advance and per-column pixel widths
    set fw [expr {(6 + $sp) * $scale}]
    set colpx {}
    for {set c 0} {$c < $ncols} {incr c} {
        set maxlen 0
        foreach r $rows {
            set cell [expr {$c < [llength $r] ? [lindex $r $c] : ""}]
            set l [string length $cell]
            if {$l > $maxlen} { set maxlen $l }
        }
        lappend colpx [expr {$maxlen * $fw + 2 * $pad}]
    }
    set rowh [expr {8 * $scale + 2 * $pad}]
    set W 0; foreach w $colpx { incr W $w }
    set H [expr {[llength $rows] * $rowh}]

    set img [::tclutils::tupngdraw::new -width $W -height $H \
        -background [dict get $o -background]]

    # row backgrounds (header + zebra)
    set y 0; set ri 0
    foreach r $rows {
        set isheader [expr {$header && $ri == 0}]
        set bg ""
        if {$isheader} {
            set bg [dict get $o -headerbg]
        } elseif {[dict get $o -zebra] ne ""} {
            set di [expr {$ri - ($header ? 1 : 0)}]
            if {$di % 2 == 1} { set bg [dict get $o -zebra] }
        }
        if {$bg ne ""} {
            $img setfill $bg
            $img rect 0 $y [expr {$W - 1}] [expr {$y + $rowh - 1}] -fill 1 -outline 0
        }
        # cell text
        set x 0
        for {set c 0} {$c < $ncols} {incr c} {
            set cw [lindex $colpx $c]
            set cell [expr {$c < [llength $r] ? [lindex $r $c] : ""}]
            set tw [expr {[string length $cell] * $fw}]
            switch -- [lindex $aligns $c] {
                r { set tx [expr {$x + $cw - $pad - $tw}] }
                c { set tx [expr {$x + ($cw - $tw) / 2}] }
                default { set tx [expr {$x + $pad}] }
            }
            set tcol [expr {$isheader ? [dict get $o -headertext] : [dict get $o -textcolor]}]
            $img text $tx [expr {$y + $pad}] $cell -color $tcol -scale $scale -spacing $sp
            incr x $cw
        }
        incr y $rowh; incr ri
    }

    # grid lines (crisp)
    if {[dict get $o -border]} {
        $img setstroke [dict get $o -gridcolor]
        $img setlinewidth 1
        $img setantialias 0
        set x 0
        $img line 0 0 0 [expr {$H - 1}]
        for {set c 0} {$c < $ncols} {incr c} {
            incr x [lindex $colpx $c]
            set lx [expr {$x < $W ? $x : $W - 1}]
            $img line $lx 0 $lx [expr {$H - 1}]
        }
        for {set ri 0} {$ri <= [llength $rows]} {incr ri} {
            set ly [expr {$ri * $rowh}]
            if {$ly > $H - 1} { set ly [expr {$H - 1}] }
            $img line 0 $ly [expr {$W - 1}] $ly
        }
    }

    set png [$img data -compression 9]
    $img destroy
    return $png
}

proc ::tclutils::tutablepng::write {file rows args} {
    set png [render $rows {*}$args]
    set fid [open $file w]
    fconfigure $fid -translation binary
    puts -nonewline $fid $png
    close $fid
    return $file
}

package provide tclutils::tutablepng 0.1
