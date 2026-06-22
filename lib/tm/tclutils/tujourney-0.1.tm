# tujourney-0.1.tm -- parse and render a Mermaid `journey` (user journey) block
# to SVG or PNG through the pure-Tcl backends (tusvg / tupngdraw), so a journey
# can be shown natively everywhere -- no browser. Like `tupie` / `tuxychart`,
# this is NOT a graph; it renders directly and is reached through the
# `tclutils::tuflow` facade (`tuflow::toPng` / `toSvg`), which dispatches
# `journey` here.
#
# Supported syntax (Mermaid subset):
#   journey                            -> header
#   title <text>                       -> chart title
#   section <name>                     -> starts a section; following tasks
#                                         belong to it
#   <task>: <score>: <actor>, <actor>  -> a task with a satisfaction score
#                                         (1..5) and an actor list; the actor
#                                         list is optional
#
# The chart shows the tasks left-to-right in source order, a line through their
# scores, section bands across the top, the actors under each task as coloured
# dots, and an actor legend.
#
# v1 limitations (honest): task names are drawn horizontally (not rotated) and
# may crowd when long or numerous; scores are plotted on a 0..max(5,data) axis;
# a section is a contiguous run of tasks (as Mermaid emits them).
#
# Namespace: ::tclutils::tujourney   Package: tclutils::tujourney 0.1
# Errors:    {TCLUTILS TUJOURNEY <REASON>}   REASON in EMPTY, ARG, FONT

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils::tujourney {
    namespace export parse toSvg toPng writeSvg writePng
    variable palette {
        #4e79a7 #f28e2b #e15759 #76b7b2 #59a14f
        #edc948 #b07aa1 #ff9da7 #9c755f #bab0ac
    }
    variable bandfill {#eaf2fb #fdf1e8 #ecf6ec #fcecec #eef7f6 #fbf6e6}
}

# --- helpers (shared shape with tupie / tuxychart / tuquadrant) -------------

proc ::tclutils::tujourney::_unquote {s} {
    set s [string trim $s]
    set n [string length $s]
    if {$n >= 2} {
        set a [string index $s 0]
        set b [string index $s end]
        if {($a eq "\"" && $b eq "\"") || ($a eq "'" && $b eq "'")} {
            return [string range $s 1 end-1]
        }
    }
    return $s
}

proc ::tclutils::tujourney::_drawText {c gfont scale x y str color} {
    if {$gfont eq "" || $str eq ""} {
        $c text $x $y $str -scale $scale -color $color
        return
    }
    set cellH   [expr {8.0 * $scale}]
    set targetW [expr {[string length $str] * 6.0 * $scale}]
    set upm [$gfont get unitsPerEm]
    set asc [$gfont get ascender]
    set dsc [$gfont get descender]
    set span [expr {$asc - $dsc}]
    set adv 0.0
    foreach ch [split $str ""] {
        set adv [expr {$adv + [$gfont gget [$gfont unicode2glyphIndex $ch] advanceWidth]}]
    }
    if {$span <= 0 || $upm <= 0 || $adv <= 0} {
        $c text $x $y $str -scale $scale -color $color
        return
    }
    set sy [expr {$cellH / double($span)}]
    set sx [expr {$targetW / ($adv * $sy)}]
    set baseline [expr {$y + $asc * $sy}]
    set pen 0.0
    foreach ch [split $str ""] {
        set gi [$gfont unicode2glyphIndex $ch]
        set aw [$gfont gget $gi advanceWidth]
        if {$gi != 0} {
            set g [$gfont glyph $gi]
            set contours {}
            foreach cont [$g onUniformSteps 6 "at"] {
                set flat {}
                foreach pt $cont {
                    lassign $pt fx fy
                    lappend flat \
                        [expr {$x + ($pen + $fx) * $sy * $sx}] \
                        [expr {$baseline - $fy * $sy}]
                }
                if {[llength $flat] >= 6} { lappend contours $flat }
            }
            if {[llength $contours]} {
                $c fillcontours $contours -color $color -rule nonzero
            }
            $g destroy
        }
        set pen [expr {$pen + $aw}]
    }
}

proc ::tclutils::tujourney::_drawCentered {c gfont scale cx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($cx - $w / 2.0)}] $ty $str $color
}

proc ::tclutils::tujourney::_drawRight {c gfont scale rx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($rx - $w)}] $ty $str $color
}

proc ::tclutils::tujourney::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 600 -height 360 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        return -code error -errorcode {TCLUTILS TUJOURNEY ARG} \
            "-scale must be a positive integer"
    }
    return $o
}

proc ::tclutils::tujourney::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} {
        return -code error -errorcode {TCLUTILS TUJOURNEY FONT} \
            "font file not found: $fontfile"
    }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""
    catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tujourney::parse {text} {
    set title ""
    set tasks {}            ;# list of {name score {actors} section}
    set sections {}         ;# ordered unique section names
    set actors {}           ;# ordered unique actor names
    set cur ""              ;# current section
    set sawHeader 0

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {!$sawHeader && [regexp -nocase {^journey\M} $line]} { set sawHeader 1; continue }
        if {[regexp -nocase {^title\s+(.+)$} $line -> t]} { set title [_unquote $t]; continue }
        if {[regexp -nocase {^section\s+(.+)$} $line -> s]} {
            set cur [_unquote [string trim $s]]
            if {$cur ni $sections} { lappend sections $cur }
            continue
        }
        # task:  name : score : actor, actor   (actors optional)
        if {[regexp {^(.+?)\s*:\s*([0-9]+)\s*(?::\s*(.*))?$} $line -> nm sc actorStr]} {
            set al {}
            foreach a [split $actorStr ,] {
                set a [string trim $a]
                if {$a eq ""} continue
                lappend al $a
                if {$a ni $actors} { lappend actors $a }
            }
            lappend tasks [list [_unquote [string trim $nm]] $sc $al $cur]
            continue
        }
    }

    if {![llength $tasks]} {
        return -code error -errorcode {TCLUTILS TUJOURNEY EMPTY} \
            "no tasks found in journey source"
    }
    return [dict create title $title tasks $tasks sections $sections actors $actors]
}

# --- draw (shared across backends) -------------------------------------------

proc ::tclutils::tujourney::_draw {c model o gfont} {
    variable palette
    variable bandfill
    set W  [$c width]
    set H  [$c height]
    set fs [dict get $o -scale]
    set np [llength $palette]
    set nb [llength $bandfill]

    set title  [dict get $model title]
    set tasks  [dict get $model tasks]
    set actors [dict get $model actors]
    set nt [llength $tasks]
    if {$nt < 1} { set nt 1 }

    # actor -> colour index (legend order)
    array set acol {}
    set ai 0
    foreach a $actors { set acol($a) [lindex $palette [expr {$ai % $np}]]; incr ai }

    # score range: 0 .. max(5, data max)
    set smax 5
    foreach t $tasks { set smax [expr {max($smax, [lindex $t 1])}] }

    set pad      [expr {12 * $fs}]
    set titleH   [expr {$title ne "" ? 18 * $fs : 0}]
    set bandH    [expr {16 * $fs}]
    set taskLabH [expr {14 * $fs}]
    set actorH   [expr {[llength $actors] ? 12 * $fs : 0}]
    set legendH  [expr {[llength $actors] ? 16 * $fs : 0}]
    set yLabW    [expr {18 * $fs}]

    set px0 [expr {$pad + $yLabW}]
    set px1 [expr {$W - $pad}]
    set plotTop [expr {$pad + $titleH + $bandH + 4 * $fs}]
    set plotBot [expr {$H - $pad - $legendH - $actorH - $taskLabH}]
    if {$px1 - $px0 < 20} { set px1 [expr {$px0 + 20}] }
    if {$plotBot - $plotTop < 20} { set plotBot [expr {$plotTop + 20}] }

    set slotW [expr {($px1 - $px0) / double($nt)}]
    set toY {s {
        upvar 1 plotTop plotTop plotBot plotBot smax smax
        expr {$plotBot - ($s / double($smax)) * ($plotBot - $plotTop)}
    }}

    if {$title ne ""} {
        _drawCentered $c $gfont $fs [expr {$W / 2.0}] $pad $title black
    }

    # section bands: contiguous runs of equal section, across the top
    set bandY0 [expr {$pad + $titleH}]
    set bandY1 [expr {$bandY0 + $bandH}]
    set i 0
    set si 0
    while {$i < [llength $tasks]} {
        set sec [lindex [lindex $tasks $i] 3]
        set j $i
        while {$j < [llength $tasks] && [lindex [lindex $tasks $j] 3] eq $sec} { incr j }
        set bx0 [expr {$px0 + $i * $slotW}]
        set bx1 [expr {$px0 + $j * $slotW}]
        set fill [lindex $bandfill [expr {$si % $nb}]]
        $c rect $bx0 $bandY0 $bx1 $bandY1 -fill 1 -fillcolor $fill -outline 0
        if {$sec ne ""} {
            _drawCentered $c $gfont $fs [expr {($bx0 + $bx1) / 2.0}] \
                [expr {int($bandY0 + 4 * $fs)}] $sec #555555
        }
        set i $j
        incr si
    }

    # score gridlines + labels (integers 1..smax)
    for {set k 1} {$k <= $smax} {incr k} {
        set yy [apply $toY $k]
        $c line $px0 $yy $px1 $yy -color #eeeeee -width $fs
        _drawRight $c $gfont $fs [expr {$px0 - 4 * $fs}] [expr {int($yy - 4 * $fs)}] $k #999999
    }

    # score line through task points
    set prevx ""; set prevy ""
    for {set i 0} {$i < [llength $tasks]} {incr i} {
        set t [lindex $tasks $i]
        set cx [expr {$px0 + ($i + 0.5) * $slotW}]
        set cy [apply $toY [lindex $t 1]]
        if {$prevx ne ""} {
            $c line $prevx $prevy $cx $cy -color #b0b0b0 -width [expr {2 * $fs}]
        }
        set prevx $cx; set prevy $cy
    }

    # task points (coloured by first actor), names, actor dots
    set r [expr {5 * $fs}]
    set dr [expr {3 * $fs}]
    for {set i 0} {$i < [llength $tasks]} {incr i} {
        set t [lindex $tasks $i]
        lassign $t nm sc al sec
        set cx [expr {$px0 + ($i + 0.5) * $slotW}]
        set cy [apply $toY $sc]
        set pcol [expr {[llength $al] ? $acol([lindex $al 0]) : "#4e79a7"}]
        $c circle $cx $cy $r -fill 1 -fillcolor $pcol -outline 1 -color white

        # task name under the plot
        _drawCentered $c $gfont $fs $cx [expr {int($plotBot + 2 * $fs)}] $nm #555555

        # actor dots in a row below the name
        if {[llength $al]} {
            set dy [expr {int($plotBot + $taskLabH + 2 * $fs)}]
            set total [expr {[llength $al] * 2 * $dr + ([llength $al] - 1) * $dr}]
            set dx [expr {$cx - $total / 2.0 + $dr}]
            foreach a $al {
                $c circle $dx [expr {$dy + $dr}] $dr -fill 1 -fillcolor $acol($a) -outline 0
                set dx [expr {$dx + 3 * $dr}]
            }
        }
    }

    # axes
    $c line $px0 $plotTop $px0 $plotBot -color #333333 -width $fs
    $c line $px0 $plotBot $px1 $plotBot -color #333333 -width $fs

    # actor legend along the bottom
    if {[llength $actors]} {
        set ly [expr {$H - $pad - $legendH + 2 * $fs}]
        set lx $px0
        set sw [expr {9 * $fs}]
        foreach a $actors {
            $c rect $lx $ly [expr {$lx + $sw}] [expr {$ly + $sw}] \
                -fill 1 -fillcolor $acol($a) -outline 0
            _drawText $c $gfont $fs [expr {$lx + $sw + 3 * $fs}] $ly $a #333333
            set lx [expr {$lx + $sw + 5 * $fs + [$c textwidth $a -scale $fs] + 10 * $fs}]
        }
    }
}

# --- public render -----------------------------------------------------------

proc ::tclutils::tujourney::toSvg {model args} {
    set o [_opts {*}$args]
    package require tclutils::tusvg 0.2
    set c [::tclutils::tusvg::new \
        -width [dict get $o -width] -height [dict get $o -height] \
        -background white]
    _draw $c $model $o ""
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tujourney::toPng {model args} {
    set o [_opts {*}$args]
    package require tclutils::tupngdraw
    set sc [dict get $o -scale]
    set c [::tclutils::tupngdraw::new \
        -width  [expr {[dict get $o -width]  * $sc}] \
        -height [expr {[dict get $o -height] * $sc}] \
        -background white]
    catch {$c setantialias 1}
    set gf [_resolveFont $c [dict get $o -fontfile]]
    if {[catch {_draw $c $model $o $gf} err opt]} {
        catch {$gf destroy}
        catch {$c destroy}
        return -options $opt $err
    }
    catch {$gf destroy}
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tujourney::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tujourney::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tujourney 0.1
