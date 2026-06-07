# tclutils::tupngpad -- normalise a set of (transparent) PNGs to a uniform size.
#
# Typical use: object cut-outs saved as transparent PNGs, each cropped to its
# own tight bounding box. This brings them all to ONE size, centres each one,
# keeps a margin around the content and flattens transparency onto a background
# colour (e.g. white).
#
#   package require tclutils::tupngpad
#   tclutils::tupngpad::batch $files /out -margin 4 -background white
#
# Pure Tcl, dependency-free, Tk-free. Built on tupng (decode/encode) and
# tupngdraw (paste/compositing).

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tupng 0.4
package require tclutils::tupngdraw 0.11

namespace eval ::tclutils {}
namespace eval ::tclutils::tupngpad {
    namespace export bbox trim padTo batch
    variable version 0.1
}

# Tight bounding box of all non-transparent pixels (alpha > 0).
# Returns {x0 y0 x1 y1} (inclusive) or {} if the image is fully transparent.
proc ::tclutils::tupngpad::bbox {rgba w h} {
    binary scan $rgba cu* p
    set minx $w; set miny $h; set maxx -1; set maxy -1
    for {set y 0} {$y < $h} {incr y} {
        set rb [expr {$y * $w * 4}]
        for {set x 0} {$x < $w} {incr x} {
            if {[lindex $p [expr {$rb + $x * 4 + 3}]] > 0} {
                if {$x < $minx} { set minx $x }
                if {$x > $maxx} { set maxx $x }
                if {$y < $miny} { set miny $y }
                if {$y > $maxy} { set maxy $y }
            }
        }
    }
    if {$maxx < 0} { return {} }
    return [list $minx $miny $maxx $maxy]
}

# Crop to the content bounding box. Returns {rgba w h}; if fully transparent,
# returns the input unchanged.
proc ::tclutils::tupngpad::trim {rgba w h} {
    set bb [bbox $rgba $w $h]
    if {$bb eq ""} { return [list $rgba $w $h] }
    lassign $bb x0 y0 x1 y1
    set nw [expr {$x1 - $x0 + 1}]
    set nh [expr {$y1 - $y0 + 1}]
    if {$nw == $w && $nh == $h} { return [list $rgba $w $h] }
    binary scan $rgba cu* p
    set out {}
    for {set y $y0} {$y <= $y1} {incr y} {
        set base [expr {($y * $w + $x0) * 4}]
        lappend out {*}[lrange $p $base [expr {$base + $nw * 4 - 1}]]
    }
    return [list [binary format cu* $out] $nw $nh]
}

# Place a content block (rgba,w,h) onto a tw x th background, returning PNG
# bytes. -background COLOR (default white); -align center|nw|n|ne|w|e|sw|s|se;
# -filter passes through to the encoder.
proc ::tclutils::tupngpad::padTo {rgba w h tw th args} {
    set o [::tclutils::common::parseOptions \
        {-background white -align center -filter {}} {*}$args]
    set img [::tclutils::tupngdraw::new \
        -width $tw -height $th -background [dict get $o -background]]
    switch -- [dict get $o -align] {
        nw { set ox 0;                 set oy 0 }
        n  { set ox [expr {($tw-$w)/2}]; set oy 0 }
        ne { set ox [expr {$tw-$w}];     set oy 0 }
        w  { set ox 0;                 set oy [expr {($th-$h)/2}] }
        e  { set ox [expr {$tw-$w}];     set oy [expr {($th-$h)/2}] }
        sw { set ox 0;                 set oy [expr {$th-$h}] }
        s  { set ox [expr {($tw-$w)/2}]; set oy [expr {$th-$h}] }
        se { set ox [expr {$tw-$w}];     set oy [expr {$th-$h}] }
        default { set ox [expr {($tw-$w)/2}]; set oy [expr {($th-$h)/2}] }
    }
    $img paste $ox $oy $rgba $w $h
    set filter [dict get $o -filter]
    if {$filter eq ""} {
        set png [$img data]
    } else {
        set png [$img data -filter $filter]
    }
    $img destroy
    return $png
}

# Batch-normalise PNG files to a uniform size. Reads each file, optionally
# trims to its content bbox, then writes every output at the SAME dimensions
# (max content size + 2*margin), content centred, on the background colour.
#
# Options: -margin N (default 4), -background COLOR (default white),
#          -trim BOOL (default 1), -align A (default center),
#          -square BOOL (default 0; make the output square),
#          -size {W H} (force inner content area; default = max over inputs).
# Returns a dict: {size {tw th} files {in out ...}}.
proc ::tclutils::tupngpad::batch {files outdir args} {
    set o [::tclutils::common::parseOptions {
        -margin 4 -background white -trim 1 -align center -square 0 -size {}
    } {*}$args]
    set margin [dict get $o -margin]
    if {![string is integer -strict $margin] || $margin < 0} {
        return -code error -errorcode {TCLUTILS TUPNGPAD MARGIN} \
            "-margin must be a non-negative integer, got: $margin"
    }

    if {![file isdirectory $outdir]} { file mkdir $outdir }

    # 1) load (and optionally trim) every image
    set items {}
    set maxW 0; set maxH 0
    foreach f $files {
        set d [::tclutils::tupng::readPNG $f]
        set rgba [dict get $d rgba]
        set w [dict get $d width]; set h [dict get $d height]
        if {[dict get $o -trim]} { lassign [trim $rgba $w $h] rgba w h }
        if {$w > $maxW} { set maxW $w }
        if {$h > $maxH} { set maxH $h }
        lappend items [list $f $rgba $w $h]
    }

    # 2) decide the uniform inner content area
    set sz [dict get $o -size]
    if {[llength $sz] == 2} {
        lassign $sz innerW innerH
    } else {
        set innerW $maxW; set innerH $maxH
    }
    if {[dict get $o -square]} {
        set m [expr {max($innerW, $innerH)}]
        set innerW $m; set innerH $m
    }
    set tw [expr {$innerW + 2 * $margin}]
    set th [expr {$innerH + 2 * $margin}]

    # 3) write each output at tw x th
    set result {}
    foreach it $items {
        lassign $it f rgba w h
        set png [padTo $rgba $w $h $tw $th \
            -background [dict get $o -background] -align [dict get $o -align]]
        set out [file join $outdir [file tail $f]]
        set fid [open $out w]
        fconfigure $fid -translation binary
        puts -nonewline $fid $png
        close $fid
        lappend result $f $out
    }
    return [dict create size [list $tw $th] files $result]
}

package provide tclutils::tupngpad 0.1
