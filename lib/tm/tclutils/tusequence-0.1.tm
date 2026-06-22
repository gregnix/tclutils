# tusequence-0.1.tm -- parse and render a Mermaid `sequenceDiagram` block to SVG
# or PNG. A self-contained 2D renderer in the tuflow family (like tugantt /
# tusankey): own parser, draws onto the shared abstract canvas (tusvg /
# tupngdraw), so SVG and PNG output stay congruent.
#
# Supported syntax (Mermaid subset):
#   sequenceDiagram
#     participant A             |  participant A as Alias  |  actor A
#     autonumber
#     A->>B: message            arrows: -> --> ->> -->> -x --x -) --)
#     A->>+B: message           +activates target, -deactivates source
#     activate A / deactivate A
#     Note left of A: text  | Note right of A: text | Note over A,B: text
#     loop / opt / alt(+else) / par(+and) / critical / break / rect ... end
#
# v1 limits: `actor` is drawn as a box (no stick figure); fragment frames span
# the full width (indented per nesting depth) rather than only the involved
# lifelines; no create/destroy, no participant boxes, no links/popups.
#
# Namespace: ::tclutils::tusequence   Package: tclutils::tusequence 0.1
# Errors:    {TCLUTILS TUSEQUENCE <REASON>}   REASON in EMPTY | ARG | FONT

package require Tcl 8.6 9
package require tclutils::common 0.1

namespace eval ::tclutils::tusequence {
    namespace export parse toSvg toPng writeSvg writePng
    variable palette {
        actorFill #ececff actorStroke #9aa0ff lifeline #b0b0b0
        msgLine #333333 noteFill #fff5ad noteStroke #d6c64b
        actBox #e8e8f8 actStroke #8a8ad0 frame #88909a frameLabelBg #eef0f3
        text #222222
    }
}

proc ::tclutils::tusequence::_err {reason msg} {
    return -code error -errorcode [list TCLUTILS TUSEQUENCE $reason] $msg
}

# --- shared 2D-renderer scaffold ---------------------------------------------

proc ::tclutils::tusequence::_opts {args} {
    set o [::tclutils::common::parseOptions \
        {-width 0 -height 0 -fontfile {} -scale 1} {*}$args]
    set sc [dict get $o -scale]
    if {![string is integer -strict $sc] || $sc < 1} {
        _err ARG "-scale must be a positive integer"
    }
    return $o
}

proc ::tclutils::tusequence::_resolveFont {c fontfile} {
    if {$fontfile eq ""} { return "" }
    if {"fillcontours" ni [info object methods $c -all]} { return "" }
    if {![file exists $fontfile]} { _err FONT "font file not found: $fontfile" }
    if {[catch {package require Glyphs}]} { return "" }
    set gf ""
    catch {set gf [Glyphs::new $fontfile]}
    return $gf
}

proc ::tclutils::tusequence::_drawText {c gfont scale x y str color} {
    if {$gfont eq "" || $str eq ""} {
        $c text $x $y $str -scale $scale -color $color
        return
    }
    set cellH   [expr {8.0 * $scale}]
    set targetW [expr {[string length $str] * 6.0 * $scale}]
    set upm  [$gfont get unitsPerEm]
    set asc  [$gfont get ascender]
    set dsc  [$gfont get descender]
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
                    lappend flat [expr {$x + ($pen + $fx) * $sy * $sx}] \
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

proc ::tclutils::tusequence::_drawCentered {c gfont scale cx ty str color} {
    set w [$c textwidth $str -scale $scale]
    _drawText $c $gfont $scale [expr {int($cx - $w/2.0)}] $ty $str $color
}

# --- arrow tokens ------------------------------------------------------------

# Map an arrow operator to {line solid|dotted  head filled|open|cross}.
proc ::tclutils::tusequence::_arrowSpec {op} {
    set line [expr {[string match "--*" $op] ? "dotted" : "solid"}]
    if {[string match "*>>" $op]} {
        set head filled
    } elseif {[string match "*x" $op]} {
        set head cross
    } else {
        set head open   ;# > and )
    }
    return [list line $line head $head]
}

# --- parse -------------------------------------------------------------------

proc ::tclutils::tusequence::parse {text} {
    set order {}             ;# participant ids in order
    set labels [dict create] ;# id -> display label
    set isActor [dict create]
    set steps {}
    set autonumber 0
    set title ""

    set addP {{id label actor} {
        upvar 1 order order labels labels isActor isActor
        if {![dict exists $labels $id]} {
            lappend order $id
            dict set labels $id [expr {$label eq "" ? $id : $label}]
            dict set isActor $id $actor
        } elseif {$label ne ""} {
            dict set labels $id $label
        }
    }}

    foreach raw [split $text \n] {
        set line [string trim $raw]
        if {$line eq "" || [string match {%%*} $line]} continue
        if {[regexp -nocase {^sequenceDiagram\M} $line]} continue
        if {[regexp -nocase {^title\s+(.*)$} $line -> t]} { set title [string trim $t]; continue }
        if {[regexp -nocase {^autonumber\M} $line]} { set autonumber 1; continue }

        # participant / actor [as alias]
        if {[regexp -nocase {^(participant|actor)\s+(.+)$} $line -> kw rest]} {
            set actor [expr {[string tolower $kw] eq "actor"}]
            if {[regexp {^(.+?)\s+as\s+(.+)$} $rest -> id lbl]} {
                apply $addP [string trim $id] [string trim $lbl] $actor
            } else {
                apply $addP [string trim $rest] "" $actor
            }
            continue
        }
        # activate / deactivate
        if {[regexp -nocase {^(activate|deactivate)\s+(.+)$} $line -> kw who]} {
            lappend steps [dict create kind [string tolower $kw] actor [string trim $who]]
            continue
        }
        # note
        if {[regexp -nocase {^note\s+(left of|right of|over)\s+(.+?)\s*:\s*(.*)$} $line -> pos who txt]} {
            set pos [string tolower [string map {{ } {}} $pos]]   ;# leftof/rightof/over
            set actors {}
            foreach a [split $who ,] {
                set a [string trim $a]
                if {$a ne ""} { lappend actors $a; apply $addP $a "" 0 }
            }
            lappend steps [dict create kind note pos $pos actors $actors text [string trim $txt]]
            continue
        }
        # block start: loop/opt/alt/par/critical/break/rect
        if {[regexp -nocase {^(loop|opt|alt|par|critical|break|rect)\y\s*(.*)$} $line -> bt lbl]} {
            lappend steps [dict create kind blockStart type [string tolower $bt] label [string trim $lbl]]
            continue
        }
        if {[regexp -nocase {^(else|and|option)\y\s*(.*)$} $line -> kw lbl]} {
            lappend steps [dict create kind blockElse label [string trim $lbl]]
            continue
        }
        if {[regexp -nocase {^end\M} $line]} {
            lappend steps [dict create kind blockEnd]
            continue
        }
        # message: FROM <op>[+/-] TO : text
        if {[regexp {^(.+?)\s*(--?(?:>>|>|x|\)))([-+]?)\s*([^:]+?)\s*:\s*(.*)$} \
                $line -> from op act to txt]} {
            set from [string trim $from]; set to [string trim $to]
            apply $addP $from "" 0
            apply $addP $to "" 0
            lappend steps [dict create kind message from $from to $to \
                op $op act $act text [string trim $txt]]
            continue
        }
    }

    if {![llength $order]} { _err EMPTY "no participants found in sequence diagram" }
    return [dict create type sequence participants $order labels $labels \
        isActor $isActor steps $steps autonumber $autonumber title $title]
}

# --- layout ------------------------------------------------------------------
# All positions are computed in logical pixels (scale 1); _draw multiplies by
# gs. Auto-sizes width/height from content unless -width/-height are given.

proc ::tclutils::tusequence::_approxW {s} { return [expr {[string length $s]*6.0 + 12}] }

proc ::tclutils::tusequence::_layout {model o} {
    set order  [dict get $model participants]
    set labels [dict get $model labels]
    set n [llength $order]

    # actor box width from the widest label
    set boxW 70.0
    foreach id $order {
        set w [_approxW [dict get $labels $id]]
        if {$w > $boxW} { set boxW $w }
    }
    set sidePad 14.0; set topPad 10.0; set botPad 12.0
    set actorH 28.0; set gap 10.0
    set colSpacing [expr {$boxW + 60.0}]
    set rowH 40.0; set selfH 30.0; set noteH 34.0
    set blkHdr 24.0; set blkPad 10.0

    # participant x centres
    set partX [dict create]
    set i 0
    foreach id $order {
        dict set partX $id [expr {$sidePad + $boxW/2.0 + $i*$colSpacing}]
        incr i
    }
    set Wauto [expr {2*$sidePad + ($n-1)*$colSpacing + $boxW}]

    set bodyTop [expr {$topPad + $actorH + $gap}]
    set y $bodyTop
    set num 0
    set auto [dict get $model autonumber]
    set actStack [dict create]   ;# actor -> list of {startY}
    set blkStack {}              ;# list of {type label y0 depth dividers}
    set msgs {}; set notes {}; set acts {}; set blocks {}

    foreach s [dict get $model steps] {
        switch [dict get $s kind] {
            message {
                set from [dict get $s from]; set to [dict get $s to]
                set self [expr {$from eq $to}]
                set msgY [expr {$y + $rowH/2.0}]
                set label [dict get $s text]
                if {$auto} { incr num; set label "$num. $label" }
                # activation shorthand
                set act [dict get $s act]
                if {$act eq "+"} {
                    dict lappend actStack $to $msgY
                } elseif {$act eq "-"} {
                    if {[dict exists $actStack $from] && [llength [dict get $actStack $from]]} {
                        set st [dict get $actStack $from]
                        set s0 [lindex $st end]
                        dict set actStack $from [lrange $st 0 end-1]
                        lappend acts [dict create actor $from y0 $s0 y1 $msgY \
                            depth [llength [dict get $actStack $from]]]
                    }
                }
                lappend msgs [dict create from $from to $to op [dict get $s op] \
                    self $self y $msgY label $label]
                set y [expr {$y + ($self ? $selfH+$rowH/2.0 : $rowH)}]
            }
            note {
                lappend notes [dict create actors [dict get $s actors] \
                    pos [dict get $s pos] text [dict get $s text] \
                    y [expr {$y+4}] h [expr {$noteH-8}]]
                set y [expr {$y + $noteH}]
            }
            activate {
                dict lappend actStack [dict get $s actor] $y
            }
            deactivate {
                set a [dict get $s actor]
                if {[dict exists $actStack $a] && [llength [dict get $actStack $a]]} {
                    set st [dict get $actStack $a]
                    set s0 [lindex $st end]
                    dict set actStack $a [lrange $st 0 end-1]
                    lappend acts [dict create actor $a y0 $s0 y1 $y \
                        depth [llength [dict get $actStack $a]]]
                }
            }
            blockStart {
                lappend blkStack [dict create type [dict get $s type] \
                    label [dict get $s label] y0 $y depth [llength $blkStack] dividers {}]
                set y [expr {$y + $blkHdr}]
            }
            blockElse {
                if {[llength $blkStack]} {
                    set top [lindex $blkStack end]
                    dict lappend top dividers [list $y [dict get $s label]]
                    lset blkStack end $top
                }
                set y [expr {$y + $blkHdr}]
            }
            blockEnd {
                if {[llength $blkStack]} {
                    set top [lindex $blkStack end]
                    set blkStack [lrange $blkStack 0 end-1]
                    dict set top y1 $y
                    lappend blocks $top
                    set y [expr {$y + $blkPad}]
                }
            }
        }
    }
    # close any still-open activations at the end of the body
    dict for {a st} $actStack {
        foreach s0 $st {
            lappend acts [dict create actor $a y0 $s0 y1 $y depth 0]
        }
    }

    set botActorY $y
    set Hauto [expr {$y + $gap + $actorH + $botPad}]

    # widen auto-width so right-side notes and self-message loops fit
    set maxRight $Wauto
    foreach nt $notes {
        set as [dict get $nt actors]; set txt [dict get $nt text]; set pos [dict get $nt pos]
        set tw [_approxW $txt]
        set xs {}; foreach a $as { lappend xs [dict get $partX $a] }
        if {$pos eq "over"} {
            set cx [expr {([tcl::mathfunc::min {*}$xs]+[tcl::mathfunc::max {*}$xs])/2.0}]
            if {[llength $as] > 1} {
                set span [expr {([tcl::mathfunc::max {*}$xs]-[tcl::mathfunc::min {*}$xs])+$tw}]
            } else { set span $tw }
            set r [expr {$cx+$span/2.0}]
        } elseif {$pos eq "rightof"} {
            set r [expr {[lindex $xs 0]+12+$tw}]
        } else { set r [lindex $xs 0] }
        if {$r > $maxRight} { set maxRight $r }
    }
    foreach m $msgs {
        if {[dict get $m self]} {
            set r [expr {[dict get $partX [dict get $m from]]+26+[_approxW [dict get $m label]]}]
            if {$r > $maxRight} { set maxRight $r }
        }
    }
    set Wauto [expr {$maxRight + $sidePad}]

    set W [dict get $o -width];  if {$W <= 0} { set W $Wauto }
    set H [dict get $o -height]; if {$H <= 0} { set H $Hauto }

    return [dict create W $W H $H order $order labels $labels \
        partX $partX boxW $boxW actorH $actorH topY $topPad \
        lifeTop [expr {$topPad+$actorH}] lifeBot $botActorY \
        botActorY $botActorY isActor [dict get $model isActor] \
        msgs $msgs notes $notes acts $acts blocks $blocks \
        sidePad $sidePad]
}

# --- draw --------------------------------------------------------------------

proc ::tclutils::tusequence::_arrowHead {c gs x y dir head color} {
    # dir: +1 head points right, -1 points left. x,y is the tip.
    set a [expr {7.0*$gs}]
    set h [expr {4.0*$gs}]
    set bx [expr {$x - $dir*$a}]
    switch -- $head {
        filled {
            $c polygon [list [expr {int($x)}] [expr {int($y)}] \
                [expr {int($bx)}] [expr {int($y-$h)}] \
                [expr {int($bx)}] [expr {int($y+$h)}]] \
                -fill 1 -fillcolor $color -outline 0
        }
        cross {
            set d [expr {4.0*$gs}]
            $c line [expr {int($x-$d)}] [expr {int($y-$d)}] [expr {int($x+$d)}] [expr {int($y+$d)}] -color $color -width 1
            $c line [expr {int($x-$d)}] [expr {int($y+$d)}] [expr {int($x+$d)}] [expr {int($y-$d)}] -color $color -width 1
        }
        default {
            $c line [expr {int($x)}] [expr {int($y)}] [expr {int($bx)}] [expr {int($y-$h)}] -color $color -width 1
            $c line [expr {int($x)}] [expr {int($y)}] [expr {int($bx)}] [expr {int($y+$h)}] -color $color -width 1
        }
    }
}

proc ::tclutils::tusequence::_dashed {c x0 y0 x1 y1 color gs} {
    set len [expr {hypot($x1-$x0,$y1-$y0)}]
    if {$len <= 0} return
    set seg [expr {5.0*$gs}]
    set steps [expr {int($len/$seg)}]
    if {$steps < 1} { set steps 1 }
    set dx [expr {($x1-$x0)/double($steps)}]
    set dy [expr {($y1-$y0)/double($steps)}]
    for {set k 0} {$k < $steps} {incr k 2} {
        set ax [expr {$x0+$k*$dx}];     set ay [expr {$y0+$k*$dy}]
        set bx [expr {$x0+($k+1)*$dx}]; set by [expr {$y0+($k+1)*$dy}]
        $c line [expr {int($ax)}] [expr {int($ay)}] [expr {int($bx)}] [expr {int($by)}] -color $color -width 1
    }
}

proc ::tclutils::tusequence::_draw {c model o gfont} {
    variable palette
    set gs [dict get $o -scale]
    set L  [_layout $model $o]
    set fs $gs
    set partX [dict get $L partX]
    set labels [dict get $L labels]
    set boxW   [dict get $L boxW]
    set actorH [dict get $L actorH]
    set W [dict get $L W]
    set actW 10.0

    proc ::tclutils::tusequence::_px {v gs} { return [expr {int($v*$gs)}] }

    # 1) lifelines + actor boxes (top)
    set lifeTop [dict get $L lifeTop]
    set lifeBot [dict get $L lifeBot]
    foreach id [dict get $L order] {
        set x [dict get $partX $id]
        _dashed $c [expr {$x*$gs}] [expr {$lifeTop*$gs}] [expr {$x*$gs}] [expr {($lifeBot+10)*$gs}] [dict get $palette lifeline] $gs
    }

    # 2) block frames (behind messages)
    foreach b [dict get $L blocks] {
        set d [dict get $b depth]
        set inset [expr {8.0*$d}]
        set x0 [expr {([dict get $L sidePad]+$inset)*$gs}]
        set x1 [expr {($W-[dict get $L sidePad]-$inset)*$gs}]
        set y0 [expr {[dict get $b y0]*$gs}]
        set y1 [expr {[dict get $b y1]*$gs}]
        # frame
        foreach {ax ay bx by} [list $x0 $y0 $x1 $y0  $x1 $y0 $x1 $y1  $x1 $y1 $x0 $y1  $x0 $y1 $x0 $y0] {
            $c line [expr {int($ax)}] [expr {int($ay)}] [expr {int($bx)}] [expr {int($by)}] -color [dict get $palette frame] -width 1
        }
        # label tab
        set typ [string toupper [dict get $b type]]
        set tw [$c textwidth $typ -scale $fs]
        set tabW [expr {$tw + 12*$gs}]
        $c rect [expr {int($x0)}] [expr {int($y0)}] [expr {int($x0+$tabW)}] [expr {int($y0+14*$gs)}] \
            -fill 1 -fillcolor [dict get $palette frameLabelBg] -outline 1 -color [dict get $palette frame]
        _drawText $c $gfont $fs [expr {int($x0+5*$gs)}] [expr {int($y0+3*$gs)}] $typ [dict get $palette text]
        set lbl [dict get $b label]
        if {$lbl ne ""} {
            _drawText $c $gfont $fs [expr {int($x0+$tabW+6*$gs)}] [expr {int($y0+3*$gs)}] "\[$lbl\]" [dict get $palette text]
        }
        # dividers (else / and)
        foreach dv [dict get $b dividers] {
            lassign $dv dy dlbl
            _dashed $c $x0 [expr {$dy*$gs}] $x1 [expr {$dy*$gs}] [dict get $palette frame] $gs
            if {$dlbl ne ""} {
                _drawText $c $gfont $fs [expr {int($x0+6*$gs)}] [expr {int($dy*$gs+3*$gs)}] "\[$dlbl\]" [dict get $palette text]
            }
        }
    }

    # 3) activation boxes
    foreach a [dict get $L acts] {
        set x [dict get $partX [dict get $a actor]]
        set off [expr {[dict get $a depth]*$actW*0.6}]
        set ax0 [expr {($x-$actW/2.0+$off)*$gs}]
        set ax1 [expr {($x+$actW/2.0+$off)*$gs}]
        $c rect [expr {int($ax0)}] [expr {int([dict get $a y0]*$gs)}] \
                [expr {int($ax1)}] [expr {int([dict get $a y1]*$gs)}] \
            -fill 1 -fillcolor [dict get $palette actBox] -outline 1 -color [dict get $palette actStroke]
    }

    # 4) notes
    foreach nt [dict get $L notes] {
        set as [dict get $nt actors]
        set pos [dict get $nt pos]
        set txt [dict get $nt text]
        set tw [$c textwidth $txt -scale $fs]
        set padW [expr {$tw + 16*$gs}]
        set y0 [expr {[dict get $nt y]*$gs}]
        set y1 [expr {([dict get $nt y]+[dict get $nt h])*$gs}]
        if {$pos eq "over"} {
            set xs {}
            foreach a $as { lappend xs [dict get $partX $a] }
            set cx [expr {([tcl::mathfunc::min {*}$xs]+[tcl::mathfunc::max {*}$xs])/2.0}]
            if {[llength $as] > 1} {
                set span [expr {([tcl::mathfunc::max {*}$xs]-[tcl::mathfunc::min {*}$xs])*$gs + $padW}]
            } else { set span $padW }
            set nx0 [expr {$cx*$gs - $span/2.0}]; set nx1 [expr {$cx*$gs + $span/2.0}]
        } else {
            set x [dict get $partX [lindex $as 0]]
            if {$pos eq "leftof"} {
                set nx1 [expr {$x*$gs - 12*$gs}]; set nx0 [expr {$nx1 - $padW}]
            } else {
                set nx0 [expr {$x*$gs + 12*$gs}]; set nx1 [expr {$nx0 + $padW}]
            }
        }
        $c rect [expr {int($nx0)}] [expr {int($y0)}] [expr {int($nx1)}] [expr {int($y1)}] \
            -fill 1 -fillcolor [dict get $palette noteFill] -outline 1 -color [dict get $palette noteStroke]
        _drawCentered $c $gfont $fs [expr {($nx0+$nx1)/2.0}] [expr {int($y0+($y1-$y0)/2.0-4*$gs)}] $txt [dict get $palette text]
    }

    # 5) messages
    foreach m [dict get $L msgs] {
        set spec [_arrowSpec [dict get $m op]]
        set col [dict get $palette msgLine]
        set y [expr {[dict get $m y]*$gs}]
        set fx [expr {[dict get $partX [dict get $m from]]*$gs}]
        set tx [expr {[dict get $partX [dict get $m to]]*$gs}]
        set label [dict get $m label]
        if {[dict get $m self]} {
            set loopW [expr {26.0*$gs}]
            set y2 [expr {$y + 22*$gs}]
            if {[dict get $spec line] eq "dotted"} {
                _dashed $c $fx $y [expr {$fx+$loopW}] $y $col $gs
                _dashed $c [expr {$fx+$loopW}] $y [expr {$fx+$loopW}] $y2 $col $gs
                _dashed $c [expr {$fx+$loopW}] $y2 $fx $y2 $col $gs
            } else {
                $c line [expr {int($fx)}] [expr {int($y)}] [expr {int($fx+$loopW)}] [expr {int($y)}] -color $col -width 1
                $c line [expr {int($fx+$loopW)}] [expr {int($y)}] [expr {int($fx+$loopW)}] [expr {int($y2)}] -color $col -width 1
                $c line [expr {int($fx+$loopW)}] [expr {int($y2)}] [expr {int($fx)}] [expr {int($y2)}] -color $col -width 1
            }
            _arrowHead $c $gs $fx $y2 -1 [dict get $spec head] $col
            _drawText $c $gfont $fs [expr {int($fx+$loopW+6*$gs)}] [expr {int($y+2*$gs)}] $label [dict get $palette text]
        } else {
            set dir [expr {$tx >= $fx ? 1 : -1}]
            set tipx [expr {$tx - $dir*($actW/2.0*$gs)}]
            set frx  [expr {$fx + $dir*($actW/2.0*$gs)}]
            if {[dict get $spec line] eq "dotted"} {
                _dashed $c $frx $y $tipx $y $col $gs
            } else {
                $c line [expr {int($frx)}] [expr {int($y)}] [expr {int($tipx)}] [expr {int($y)}] -color $col -width 1
            }
            _arrowHead $c $gs $tipx $y $dir [dict get $spec head] $col
            _drawCentered $c $gfont $fs [expr {($frx+$tipx)/2.0}] [expr {int($y-12*$gs)}] $label [dict get $palette text]
        }
    }

    # 6) actor boxes (top and bottom)
    foreach band [list [dict get $L topY] [expr {[dict get $L botActorY]+10}]] {
        foreach id [dict get $L order] {
            set x [dict get $partX $id]
            set bx0 [expr {($x-$boxW/2.0)*$gs}]; set bx1 [expr {($x+$boxW/2.0)*$gs}]
            set by0 [expr {$band*$gs}]; set by1 [expr {($band+$actorH)*$gs}]
            $c rect [expr {int($bx0)}] [expr {int($by0)}] [expr {int($bx1)}] [expr {int($by1)}] \
                -fill 1 -fillcolor [dict get $palette actorFill] -outline 1 -color [dict get $palette actorStroke]
            _drawCentered $c $gfont $fs [expr {$x*$gs}] [expr {int($by0+($actorH/2.0-4)*$gs)}] \
                [dict get $labels $id] [dict get $palette text]
        }
    }
}

# --- backends ----------------------------------------------------------------

proc ::tclutils::tusequence::toSvg {model args} {
    set o [_opts {*}$args]
    set L [_layout $model $o]
    package require tclutils::tusvg 0.2
    set c [::tclutils::tusvg::new \
        -width [expr {int([dict get $L W])}] -height [expr {int([dict get $L H])}] -background white]
    _draw $c $model $o ""
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tusequence::toPng {model args} {
    set o [_opts {*}$args]
    set L [_layout $model $o]
    set sc [dict get $o -scale]
    package require tclutils::tupngdraw
    set c [::tclutils::tupngdraw::new \
        -width  [expr {int([dict get $L W]*$sc)}] \
        -height [expr {int([dict get $L H]*$sc)}] -background white]
    catch {$c setantialias 1}
    set gf [_resolveFont $c [dict get $o -fontfile]]
    if {[catch {_draw $c $model $o $gf} err opt]} {
        catch {$gf destroy}; catch {$c destroy}
        return -options $opt $err
    }
    catch {$gf destroy}
    set out [$c data]
    $c destroy
    return $out
}

proc ::tclutils::tusequence::writeSvg {model file args} {
    set svg [toSvg $model {*}$args]
    set fh [open $file w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts -nonewline $fh $svg
    close $fh
    return $file
}

proc ::tclutils::tusequence::writePng {model file args} {
    set png [toPng $model {*}$args]
    set fh [open $file wb]
    puts -nonewline $fh $png
    close $fh
    return $file
}

package provide tclutils::tusequence 0.1
