# tclutils::tumd -- small Markdown helpers (CommonMark subset, GFM tables)
# Description: small Markdown helpers (CommonMark subset, GFM tables)
# Category: Data · structures & formats
# Tcl 8.6+
#
# A dependency-free Markdown utility: convert Markdown to an HTML fragment,
# extract headings, build a table of contents, and split off YAML front
# matter.
#
# Blocks: ATX and setext headings, paragraphs, fenced and indented code,
# blockquotes, ordered and unordered lists (nested, continuation lines,
# tight and loose, task items), GFM tables, horizontal rules, link reference
# definitions, footnotes.
# Inline: code spans, backslash escapes, entities, **bold**/__bold__,
# *italic*/_italic_, ~~strikethrough~~, inline and reference links and images
# (with title, URLs with parentheses), <autolinks>, bare URLs (https://...,
# www....), footnote references, hard line breaks (two trailing spaces or a
# backslash).
# Raw HTML in the input is escaped, never passed through.
#
# parse returns the blocks with the link definitions and footnotes of the
# document (for viewers and editors; -lines 1 adds line numbers), inline and
# paragraph convert the Markdown of one block to HTML with those
# definitions, unescape turns that HTML text back into characters. HTML
# comments are hidden.
#
# 0.3: GFM tables; lists with continuation lines, nesting, loose items and
# task items; setext headings; indented code; reference links; link titles;
# URLs with parentheses; bare URLs; entities; footnotes; backslash escapes;
# strikethrough; emphasis across line breaks; e-mail autolinks; CRLF input.
# headings and toc see setext headings too. New: parse, inline, paragraph, unescape;
# toHtml options -page -title -css -lang -linkmap -headingoffset.
# 0.2: heading anchors as GitHub makes them: letters and digits of every
# script stay (Jörg -> jörg, 0.1 gave jrg), "_" stays, a repeated anchor
# gets -1, -2 ... in toc and toHtml (0.1 gave Jörg and Jrg the same id).

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tumd {
    namespace export toHtml headings toc frontmatter parse inline paragraph unescape
    variable version 0.3
    # Link reference definitions of the document being converted.
    variable refs {}
    # Heading anchors used so far in the document being converted.
    variable seen {}
    # Footnotes of the document: key -> number; references made so far.
    variable notes {}
    variable noteRefs {}
    # toHtml options in effect while converting.
    variable linkmap {}
    variable hoff 0
    # Named entities that are recognized (HTML names -> character).
    variable entities {
        amp & lt < gt > quot \" apos ' nbsp \u00a0 shy \u00ad
        copy \u00a9 reg \u00ae trade \u2122 euro \u20ac cent \u00a2
        pound \u00a3 yen \u00a5 sect \u00a7 para \u00b6 deg \u00b0
        plusmn \u00b1 times \u00d7 divide \u00f7 micro \u00b5 middot \u00b7
        sup2 \u00b2 sup3 \u00b3 frac12 \u00bd frac14 \u00bc frac34 \u00be
        auml \u00e4 ouml \u00f6 uuml \u00fc Auml \u00c4 Ouml \u00d6
        Uuml \u00dc szlig \u00df eacute \u00e9 egrave \u00e8 agrave \u00e0
        ccedil \u00e7 ntilde \u00f1 hellip \u2026 mdash \u2014 ndash \u2013
        laquo \u00ab raquo \u00bb bdquo \u201e ldquo \u201c rdquo \u201d
        sbquo \u201a lsquo \u2018 rsquo \u2019 bull \u2022 larr \u2190
        rarr \u2192 uarr \u2191 darr \u2193 harr \u2194 rArr \u21d2
        ne \u2260 le \u2264 ge \u2265 infin \u221e
    }
    # Backslash escape: a backslash before ASCII punctuation.
    variable escRE "\\\\(\[!-/:-@\\\[-`\{-~\])"
}

proc ::tclutils::tumd::_escape {s} {
    return [string map {& &amp; < &lt; > &gt; \" &quot;} $s]
}

# GitHub-style heading slug: lower case, Markdown marks * and ` removed,
# everything but letters, digits, "_", "-" and blanks removed, blanks -> "-".
proc ::tclutils::tumd::_slug {text} {
    set s [string tolower [string trim $text]]
    regsub -all {[*`]} $s "" s
    regsub -all {[^[:alnum:]_ -]} $s "" s
    regsub -all { } $s "-" s
    return $s
}

# The slug of TEXT, made unique against the dict in SEENVAR (-1, -2 ...).
proc ::tclutils::tumd::_uniqueSlug {seenVar text} {
    upvar 1 $seenVar seen
    set base [_slug $text]
    set slug $base
    set k 0
    while {[dict exists $seen $slug]} {
        set slug "$base-[incr k]"
    }
    dict set seen $slug 1
    return $slug
}

# ---- line classification ----------------------------------------------------

# Width of the leading white space in columns (tab stops every 4).
proc ::tclutils::tumd::_indent {line} {
    regexp {^[ \t]*} $line ws
    set col 0
    foreach c [split $ws ""] {
        if {$c eq " "} {
            incr col
        } else {
            set col [expr {($col / 4 + 1) * 4}]
        }
    }
    return $col
}

# LINE with W columns of leading white space removed.
proc ::tclutils::tumd::_dedent {line w} {
    regexp {^[ \t]*} $line ws
    set col 0
    set k 0
    foreach c [split $ws ""] {
        if {$col >= $w} break
        if {$c eq " "} {
            incr col
        } else {
            set col [expr {($col / 4 + 1) * 4}]
        }
        incr k
    }
    set rest [string range $line $k end]
    if {$col > $w} {
        set rest "[string repeat " " [expr {$col - $w}]]$rest"
    }
    return $rest
}

proc ::tclutils::tumd::_blank {line} {
    expr {[string trim $line] eq ""}
}

proc ::tclutils::tumd::_isHr {line} {
    regexp {^[ ]{0,3}([-*_])[ \t]*(?:\1[ \t]*){2,}$} $line
}

# A list item line: {indent marker ordered start contentColumn content},
# or "" for any other line.
proc ::tclutils::tumd::_listItem {line} {
    if {![regexp {^([ ]{0,3})([-*+]|[0-9]{1,9}[.)])(?:([ \t]+)(.*))?$} \
            $line -> ind marker sp content]} {
        return ""
    }
    set ordered [string is digit [string index $marker 0]]
    set start [expr {$ordered ? [scan [string range $marker 0 end-1] %d] : 1}]
    set w [expr {[string length $ind] + [string length $marker]}]
    set nsp [string length $sp]
    if {$content eq ""} {
        incr w
    } elseif {$nsp > 4} {
        # The content is indented code: the item starts one column in.
        incr w
        set content "[string repeat " " [expr {$nsp - 1}]]$content"
    } else {
        incr w $nsp
    }
    return [list $ind $marker $ordered $start $w $content]
}

# Does LINE start a block that ends a list item's lazy continuation?
proc ::tclutils::tumd::_isStart {line} {
    expr {[regexp {^[ ]{0,3}(```|~~~|#{1,6}([ \t]|$)|>|<!--)} $line]
          || [_isHr $line] || [_listItem $line] ne ""}
}

# Does LINE end a paragraph? As _isStart, but a list item only interrupts
# a paragraph when it has content and, if ordered, starts with 1.
proc ::tclutils::tumd::_interrupts {line} {
    if {[regexp {^[ ]{0,3}(```|~~~|#{1,6}([ \t]|$)|>|<!--)} $line] || [_isHr $line]} {
        return 1
    }
    set li [_listItem $line]
    if {$li eq ""} {
        return 0
    }
    lassign $li ind marker ordered start w content
    expr {[string trim $content] ne "" && (!$ordered || $start == 1)}
}

# ---- GFM tables -----------------------------------------------------------------

# The cells of a table row; an escaped \| stays in the cell.
proc ::tclutils::tumd::_cells {line} {
    set s [string trim $line]
    if {[string index $s 0] eq "|"} {
        set s [string range $s 1 end]
    }
    if {[string index $s end] eq "|" && [string index $s end-1] ne "\\"} {
        set s [string range $s 0 end-1]
    }
    set cells {}
    set cur ""
    set esc 0
    foreach c [split $s ""] {
        if {$esc} {
            append cur $c
            set esc 0
        } elseif {$c eq "\\"} {
            append cur $c
            set esc 1
        } elseif {$c eq "|"} {
            lappend cells [string trim $cur]
            set cur ""
        } else {
            append cur $c
        }
    }
    lappend cells [string trim $cur]
    return $cells
}

proc ::tclutils::tumd::_isSep {line} {
    expr {[string first | $line] >= 0 && [regexp \
        {^[ ]{0,3}\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$} $line]}
}

proc ::tclutils::tumd::_aligns {line} {
    set al {}
    foreach c [_cells $line] {
        set l [string match :* $c]
        set r [string match *: $c]
        lappend al [expr {$l && $r ? "center" : $l ? "left" : $r ? "right" : ""}]
    }
    return $al
}

# Does a table (header row and separator row) start at line I?
proc ::tclutils::tumd::_tableAt {lines i} {
    set h [lindex $lines $i]
    if {[string first | $h] < 0 || $i + 1 >= [llength $lines]} {
        return 0
    }
    set s [lindex $lines [expr {$i + 1}]]
    expr {[_isSep $s] && [llength [_cells $h]] == [llength [_cells $s]]}
}

# ---- block parser ---------------------------------------------------------------

proc ::tclutils::tumd::_refKey {label} {
    string tolower [regsub -all {\s+} [string trim $label] " "]
}

# Parse LINES into a list of blocks:
#   {h level text}  {p lines}  {code lang text}  {hr}  {quote blocks}
#   {list ordered start loose items}  (item: {task blocks}, task "", open, done)
#   {table aligns header rows}  {footnote key number blocks}  {comment text}
#   (list: a sixth element, the marker - * + or the delimiter . ))
# (heading ids and footnote numbers are filled in by _number).
# Link reference definitions go to the namespace variable refs. If GAPVAR is
# given, it is set to 1 when blank lines separate two blocks (loose item).
# POSVAR gets {first last} (lines from 1) per block, DEFSVAR
# {key first last} per link reference definition.
proc ::tclutils::tumd::_parse {lines {gapVar ""} {posVar ""} {defsVar ""}} {
    variable refs
    if {$gapVar ne ""} {
        upvar 1 $gapVar gap
        set gap 0
    }
    if {$posVar ne ""} {
        upvar 1 $posVar pos
        set pos {}
    }
    if {$defsVar ne ""} {
        upvar 1 $defsVar defs
        set defs {}
    }
    set blocks {}
    set n [llength $lines]
    set i 0
    set blank 0
    set bstart 0
    while 1 {
        # the lines of the block appended last
        if {$posVar ne "" && [llength $blocks] > [llength $pos]} {
            lappend pos [list [expr {$bstart + 1}] [_lastLine $lines $bstart $i]]
        }
        if {$i >= $n} break
        set line [lindex $lines $i]

        if {[_blank $line]} {
            if {[llength $blocks]} {
                set blank 1
            }
            incr i
            continue
        }
        if {$blank && $gapVar ne ""} {
            set gap 1
        }
        set blank 0
        set bstart $i

        # HTML comment: hidden; up to the line with -->.
        if {[regexp {^[ ]{0,3}<!--} $line]} {
            set c {}
            while {$i < $n} {
                set l [lindex $lines $i]
                lappend c $l
                incr i
                if {[string first --> $l [expr {[string first <!-- $l] + 4}]] >= 0
                        || ([llength $c] > 1 && [string first --> $l] >= 0)} break
            }
            lappend blocks [list comment [join $c \n]]
            continue
        }

        # Fenced code; it ends at a closing fence of the same kind or at the end.
        if {[regexp {^([ ]{0,3})(`{3,}|~{3,})[ \t]*([^ \t`]*)[^`]*$} \
                $line -> ind fence lang]} {
            set fc [string index $fence 0]
            set fl [string length $fence]
            set code {}
            incr i
            while {$i < $n} {
                set l [lindex $lines $i]
                if {[regexp {^[ ]{0,3}([`~]{3,})[ \t]*$} $l -> cf]
                        && [string length $cf] >= $fl
                        && [string map [list $fc ""] $cf] eq ""} {
                    incr i
                    break
                }
                lappend code [_dedent $l [string length $ind]]
                incr i
            }
            lappend blocks [list code $lang [join $code \n]]
            continue
        }

        # Indented code (four columns).
        if {[_indent $line] >= 4} {
            set code {}
            while {$i < $n} {
                set l [lindex $lines $i]
                if {[_blank $l]} {
                    lappend code ""
                } elseif {[_indent $l] >= 4} {
                    lappend code [_dedent $l 4]
                } else {
                    break
                }
                incr i
            }
            while {[llength $code] && [lindex $code end] eq ""} {
                set code [lrange $code 0 end-1]
            }
            lappend blocks [list code "" [join $code \n]]
            continue
        }

        # ATX heading; a closing run of # goes.
        if {[regexp {^[ ]{0,3}(#{1,6})(?:[ \t]+(.*))?$} $line -> hashes htext]} {
            regsub {(?:^|[ \t]+)#+[ \t]*$} $htext "" htext
            lappend blocks [list h [string length $hashes] [string trim $htext]]
            incr i
            continue
        }

        if {[_isHr $line]} {
            lappend blocks [list hr]
            incr i
            continue
        }

        # Blockquote, with lazy continuation lines.
        if {[regexp {^[ ]{0,3}>} $line]} {
            set q {}
            while {$i < $n} {
                set l [lindex $lines $i]
                if {[regexp {^[ ]{0,3}>[ ]?(.*)$} $l -> c]} {
                    lappend q $c
                } elseif {![_blank $l] && [llength $q]
                        && ![_blank [lindex $q end]] && ![_isStart $l]} {
                    lappend q $l
                } else {
                    break
                }
                incr i
            }
            lappend blocks [list quote [_parse $q]]
            continue
        }

        # List.
        set li [_listItem $line]
        if {$li ne ""} {
            lassign $li ind marker ordered start w first
            set kind [string index $marker end]
            set items {}
            set loose 0
            while 1 {
                set body [list $first]
                incr i
                while {$i < $n} {
                    set l [lindex $lines $i]
                    if {[_blank $l]} {
                        set j $i
                        while {$j < $n && [_blank [lindex $lines $j]]} {
                            incr j
                        }
                        if {$j < $n && [_indent [lindex $lines $j]] >= $w} {
                            for {} {$i < $j} {incr i} {
                                lappend body ""
                            }
                            continue
                        }
                        break
                    }
                    if {[_indent $l] >= $w} {
                        lappend body [_dedent $l $w]
                    } elseif {![_blank [lindex $body end]] && ![_isStart $l]} {
                        # lazy continuation of the item's paragraph
                        lappend body [string trimleft $l]
                    } else {
                        break
                    }
                    incr i
                }
                set task ""
                if {[regexp {^\[([ xX])\][ \t]+(.*)$} [lindex $body 0] -> box rest]} {
                    set task [expr {$box eq " " ? "open" : "done"}]
                    lset body 0 $rest
                }
                set g 0
                set ib [_parse $body g]
                if {$g} {
                    set loose 1
                }
                lappend items [list $task $ib]

                # Next item of the same list?
                set j $i
                while {$j < $n && [_blank [lindex $lines $j]]} {
                    incr j
                }
                if {$j >= $n} {
                    set i $j
                    break
                }
                set nl [lindex $lines $j]
                if {[_isHr $nl]} break
                set nli [_listItem $nl]
                if {$nli eq ""} break
                lassign $nli ind2 marker2 ordered2 start2 w2 first2
                if {$ordered2 != $ordered || [string index $marker2 end] ne $kind} break
                if {$j > $i} {
                    set loose 1
                }
                set i $j
                set w $w2
                set first $first2
            }
            lappend blocks [list list $ordered $start $loose $items $kind]
            continue
        }

        # Footnote definition: [^label]: text, continued by indented lines.
        if {[regexp {^[ ]{0,3}\[\^([^\]\s]+)\]:[ \t]?(.*)$} $line -> label first]} {
            set body [list $first]
            incr i
            while {$i < $n} {
                set l [lindex $lines $i]
                if {[_blank $l]} {
                    set j $i
                    while {$j < $n && [_blank [lindex $lines $j]]} {
                        incr j
                    }
                    if {$j < $n && [_indent [lindex $lines $j]] >= 4} {
                        for {} {$i < $j} {incr i} {
                            lappend body ""
                        }
                        continue
                    }
                    break
                }
                if {[_indent $l] >= 4} {
                    lappend body [_dedent $l 4]
                } elseif {![_blank [lindex $body end]] && ![_isStart $l]
                        && ![regexp {^[ ]{0,3}\[\^[^\]\s]+\]:} $l]} {
                    lappend body [string trimleft $l]
                } else {
                    break
                }
                incr i
            }
            lappend blocks [list footnote [_refKey [_escape $label]] 0 [_parse $body]]
            continue
        }

        # Link reference definition: [label]: url "title"
        if {[regexp {^[ ]{0,3}\[([^\]]+)\]:[ \t]*(\S+)(?:[ \t]+("[^"]*"|'[^']*'|\([^)]*\)))?[ \t]*$} \
                $line -> label url title]} {
            set key [_refKey [_escape $label]]
            if {![dict exists $refs $key]} {
                if {[string match <*> $url]} {
                    set url [string range $url 1 end-1]
                }
                dict set refs $key [list $url [string range $title 1 end-1]]
            }
            if {$defsVar ne ""} {
                lappend defs [list $key [expr {$i + 1}] [expr {$i + 1}]]
            }
            incr i
            continue
        }

        # GFM table.
        if {[_tableAt $lines $i]} {
            set head [_cells $line]
            set al [_aligns [lindex $lines [expr {$i + 1}]]]
            set nc [llength $head]
            set rows {}
            incr i 2
            while {$i < $n} {
                set l [lindex $lines $i]
                if {[_blank $l] || [_isStart $l]} break
                set c [_cells $l]
                while {[llength $c] < $nc} {
                    lappend c ""
                }
                lappend rows [lrange $c 0 [expr {$nc - 1}]]
                incr i
            }
            lappend blocks [list table $al $head $rows]
            continue
        }

        # Paragraph, or a setext heading when underlined with = or -.
        set para [list $line]
        set lvl 0
        incr i
        while {$i < $n} {
            set l [lindex $lines $i]
            if {[_blank $l]} break
            if {[regexp {^[ ]{0,3}(=+|-+)[ \t]*$} $l -> u]} {
                set lvl [expr {[string index $u 0] eq "=" ? 1 : 2}]
                incr i
                break
            }
            if {[_interrupts $l] || [_tableAt $lines $i]} break
            lappend para $l
            incr i
        }
        if {$lvl} {
            set t {}
            foreach p $para {
                lappend t [string trim $p]
            }
            lappend blocks [list h $lvl [join $t " "]]
        } else {
            lappend blocks [list p $para]
        }
    }
    return $blocks
}

# Last line (from 1) of a block that started at index START and ends before
# index END: trailing blank lines do not count.
proc ::tclutils::tumd::_lastLine {lines start end} {
    set k [expr {$end - 1}]
    while {$k > $start && [_blank [lindex $lines $k]]} {
        incr k -1
    }
    return [expr {$k + 1}]
}

# ---- inline -------------------------------------------------------------------

# Replace each match of RE in the variable SVAR. CMD gets the submatches and
# returns {ok before text after}: before and after are HTML kept away from
# later steps (placeholders in PHVAR), text stays in place. ok 0 leaves the
# match as it is.
proc ::tclutils::tumd::_sub {sVar phVar re cmd} {
    upvar 1 $sVar s $phVar ph
    set out ""
    set pos 0
    while {[set m [regexp -start $pos -indices -inline -- $re $s]] ne ""} {
        lassign [lindex $m 0] a b
        set subs {}
        foreach p [lrange $m 1 end] {
            lassign $p x y
            lappend subs [expr {$x < 0 ? "" : [string range $s $x $y]}]
        }
        append out [string range $s $pos [expr {$a - 1}]]
        lassign [{*}$cmd {*}$subs] ok before text after
        if {$ok} {
            foreach {piece raw} [list $before 0 $text 1 $after 0] {
                if {$piece eq ""} continue
                if {$raw} {
                    append out $piece
                } else {
                    append out "\x00[llength $ph]\x00"
                    lappend ph $piece
                }
            }
            set pos [expr {$b + 1}]
        } else {
            append out [string index $s $a]
            set pos [expr {$a + 1}]
        }
    }
    set s "$out[string range $s $pos end]"
}

proc ::tclutils::tumd::_rCode {c} {
    list 1 "<code>[_escape [string map {\n " "} $c]]</code>" "" ""
}

# An HTML comment in the text: hidden.
proc ::tclutils::tumd::_rComment {c} {
    list 1 "" "" ""
}

proc ::tclutils::tumd::_rEsc {c} {
    list 1 [_escape $c] "" ""
}

proc ::tclutils::tumd::_rUrl {u} {
    set u [_escape $u]
    list 1 "<a href=\"$u\">$u</a>" "" ""
}

proc ::tclutils::tumd::_rMail {m} {
    set m [_escape $m]
    list 1 "<a href=\"mailto:$m\">$m</a>" "" ""
}

proc ::tclutils::tumd::_rEntity {e} {
    variable entities
    if {[string index $e 0] eq "#" || [dict exists $entities $e]} {
        return [list 1 "&$e;" "" ""]
    }
    return {0}
}

# A footnote reference [^label]: superscript number linking to the note.
proc ::tclutils::tumd::_rNote {label} {
    variable notes
    variable noteRefs
    set key [_refKey $label]
    if {![dict exists $notes $key]} {
        return {0}
    }
    set n [dict get $notes $key]
    dict incr noteRefs $n
    set k [dict get $noteRefs $n]
    set id [expr {$k == 1 ? "fnref-$n" : "fnref-$n-$k"}]
    list 1 "<sup id=\"$id\"><a href=\"#fn-$n\">$n</a></sup>" "" ""
}

# Apply toHtml -linkmap (suffix pairs) to a relative link target.
proc ::tclutils::tumd::_mapLink {url} {
    variable linkmap
    if {![llength $linkmap] || [regexp {^[A-Za-z][A-Za-z0-9+.-]*:|^#} $url]} {
        return $url
    }
    set frag ""
    set p [string first # $url]
    if {$p >= 0} {
        set frag [string range $url $p end]
        set url [string range $url 0 [expr {$p - 1}]]
    }
    foreach {from to} $linkmap {
        set k [string length $from]
        if {$k && [string range $url end-[expr {$k - 1}] end] eq $from} {
            set url "[string range $url 0 end-$k]$to"
            break
        }
    }
    return $url$frag
}

# Is position END of S (escaped, with placeholders) inside a link's text?
proc ::tclutils::tumd::_inAnchor {s ph} {
    set d 0
    foreach {- k} [regexp -all -inline {\x00([0-9]+)\x00} $s] {
        set v [lindex $ph $k]
        if {[string match {<a *} $v] && [string first </a> $v] < 0} {
            incr d
        } elseif {$v eq "</a>"} {
            incr d -1
        }
    }
    expr {$d > 0}
}

# Bare URLs (https://..., http://..., www....) in the escaped text S become
# links; trailing punctuation and an unbalanced ")" stay outside.
proc ::tclutils::tumd::_bareUrls {sVar phVar} {
    upvar 1 $sVar s $phVar ph
    set re {(?:https?://|www\.)[^\s&\x00]*(?:&amp;[^\s&\x00]*)*}
    set out ""
    set pos 0
    while {[regexp -start $pos -indices -- $re $s m]} {
        lassign $m a b
        set prev [expr {$a > 0 ? [string index $s [expr {$a - 1}]] : " "}]
        if {![regexp {[\s*_~(]} $prev] || [_inAnchor [string range $s 0 [expr {$a - 1}]] $ph]} {
            append out [string range $s $pos $a]
            set pos [expr {$a + 1}]
            continue
        }
        set u [string range $s $a $b]
        while 1 {
            if {[regexp {[?!.,:*_~]$} $u]} {
                set u [string range $u 0 end-1]
            } elseif {[string index $u end] eq ")"
                    && [regexp -all {\(} $u] < [regexp -all {\)} $u]} {
                set u [string range $u 0 end-1]
            } else {
                break
            }
        }
        if {![regexp {^(?:https?://|www\.)[^/]*[A-Za-z0-9]} $u]} {
            append out [string range $s $pos $a]
            set pos [expr {$a + 1}]
            continue
        }
        set href [expr {[string match www.* $u] ? "http://$u" : $u}]
        append out [string range $s $pos [expr {$a - 1}]] "\x00[llength $ph]\x00"
        lappend ph "<a href=\"$href\">$u</a>"
        set pos [expr {$a + [string length $u]}]
    }
    set s "$out[string range $s $pos end]"
}

# Title of an inline link, already escaped, with its quotes.
proc ::tclutils::tumd::_title {t} {
    if {$t eq ""} {
        return ""
    }
    if {[string match {&quot;*} $t]} {
        set t [string range $t 6 end-6]
    } else {
        set t [string range $t 1 end-1]
    }
    return " title=\"$t\""
}

# Link or image for URL and TITLE (both escaped). IMG: alt text or "".
proc ::tclutils::tumd::_link {img text url title} {
    if {$img} {
        return [list 1 "<img src=\"$url\" alt=\"$text\"$title>" "" ""]
    }
    list 1 "<a href=\"[_mapLink $url]\"$title>" $text "</a>"
}

proc ::tclutils::tumd::_rInline {img text url title} {
    _link $img $text $url [_title $title]
}

# A reference link: LABEL "" means the text is the label.
proc ::tclutils::tumd::_rRef {img text {label ""}} {
    variable refs
    if {$label eq ""} {
        set label $text
    }
    set key [_refKey $label]
    if {![dict exists $refs $key]} {
        return {0}
    }
    lassign [dict get $refs $key] url title
    set t [expr {$title eq "" ? "" : " title=\"[_escape $title]\""}]
    _link $img $text [_escape $url] $t
}

# Convert inline Markdown to HTML.
proc ::tclutils::tumd::_inline {s} {
    variable escRE
    set ph {}
    # Code spans first; an escaped backtick does not open one.
    _sub s ph {\\(`)} ::tclutils::tumd::_rEsc
    _sub s ph {``((?:[^`]|`(?!`))+)``} ::tclutils::tumd::_rCode
    _sub s ph {`([^`]+)`} ::tclutils::tumd::_rCode
    _sub s ph {<!--((?:[^-]|-(?!->))*)-->} ::tclutils::tumd::_rComment
    _sub s ph $escRE ::tclutils::tumd::_rEsc
    _sub s ph {<(https?://[^\s<>]+)>} ::tclutils::tumd::_rUrl
    _sub s ph {<([^\s<>@]+@[^\s<>@]+\.[^\s<>@]+)>} ::tclutils::tumd::_rMail
    _sub s ph {&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[A-Za-z][A-Za-z0-9]{1,31});} \
        ::tclutils::tumd::_rEntity
    set s [_escape $s]
    _sub s ph {\[\^([^\]\s]+)\]} ::tclutils::tumd::_rNote
    # Images, then links; inline, then reference, then shortcut reference.
    set dest {\(((?:[^()\s]|\([^()\s]*\))*)(?:\s+(&quot;(?:[^&]|&(?!quot;))*&quot;|'[^']*'))?\s*\)}
    _sub s ph "!\\\[(\[^\\\]\]*)\\\]$dest" {::tclutils::tumd::_rInline 1}
    _sub s ph {!\[([^\]]*)\]\[([^\]]*)\]} {::tclutils::tumd::_rRef 1}
    _sub s ph {!\[([^\]]+)\](?![(\[])} {::tclutils::tumd::_rRef 1}
    _sub s ph "\\\[(\[^\\\]\]*)\\\]$dest" {::tclutils::tumd::_rInline 0}
    _sub s ph {\[([^\]]+)\]\[([^\]]*)\]} {::tclutils::tumd::_rRef 0}
    _sub s ph {\[([^\]]+)\](?![(\[])} {::tclutils::tumd::_rRef 0}
    _bareUrls s ph
    # Emphasis: bold, italic, bold again for **a *b* c**.
    set strong {\*\*([^*\s](?:[^*]*[^*\s])?)\*\*}
    regsub -all $strong $s {<strong>\1</strong>} s
    regsub -all {(^|[^\w])__([^_\s](?:[^_]*[^_\s])?)__(?=[^\w]|$)} $s \
        {\1<strong>\2</strong>} s
    regsub -all {~~([^~\s](?:[^~]*[^~\s])?)~~} $s {<del>\1</del>} s
    regsub -all {\*([^*\s](?:[^*]*[^*\s])?)\*} $s {<em>\1</em>} s
    regsub -all {(^|[^\w])_([^_\s](?:[^_]*[^_\s])?)_(?=[^\w]|$)} $s \
        {\1<em>\2</em>} s
    regsub -all $strong $s {<strong>\1</strong>} s
    # Restore placeholders, latest first (an image alt may hold older ones).
    for {set k [expr {[llength $ph] - 1}]} {$k >= 0} {incr k -1} {
        set s [string map [list "\x00$k\x00" [lindex $ph $k]] $s]
    }
    return $s
}

# The inline HTML of a paragraph; hard breaks from two trailing spaces or a
# trailing backslash.
proc ::tclutils::tumd::_para {lines} {
    set n [llength $lines]
    set k 0
    set text ""
    foreach l $lines {
        incr k
        set t [string trim $l]
        set br 0
        if {$k < $n} {
            if {[regexp {  +$} $l]} {
                set br 1
            } elseif {[regexp {\\+$} $t bs] && [string length $bs] % 2} {
                set br 1
                set t [string range $t 0 end-1]
            }
        }
        append text $t [expr {$br ? "\x00B\x00" : ""}] [expr {$k < $n ? "\n" : ""}]
    }
    string map [list "\x00B\x00" <br>] [_inline $text]
}

# ---- rendering ----------------------------------------------------------------

proc ::tclutils::tumd::_render {blocks tight} {
    set out {}
    foreach b $blocks {
        switch -- [lindex $b 0] {
            h {
                variable hoff
                lassign $b - lvl text id
                set lvl [expr {min(6, $lvl + $hoff)}]
                lappend out "<h$lvl id=\"$id\">[_inline $text]</h$lvl>"
            }
            footnote - comment {
                # footnotes are written at the end; comments are hidden
            }
            p {
                set t [_para [lindex $b 1]]
                lappend out [expr {$tight ? $t : "<p>$t</p>"}]
            }
            code {
                lassign $b - lang text
                set cls ""
                if {$lang ne ""} {
                    set cls " class=\"language-[_escape $lang]\""
                }
                lappend out "<pre><code$cls>[_escape $text]</code></pre>"
            }
            hr {
                lappend out "<hr>"
            }
            quote {
                lappend out "<blockquote>\n[_render [lindex $b 1] 0]\n</blockquote>"
            }
            list {
                lassign $b - ordered start loose items
                set tag [expr {$ordered ? "ol" : "ul"}]
                set attr ""
                if {$ordered && $start != 1} {
                    set attr " start=\"$start\""
                }
                set lis ""
                foreach it $items {
                    lassign $it task ib
                    set inner [_render $ib [expr {!$loose}]]
                    set box ""
                    if {$task eq "open"} {
                        set box {<input type="checkbox" disabled> }
                    } elseif {$task eq "done"} {
                        set box {<input type="checkbox" checked disabled> }
                    }
                    if {!$loose} {
                        append lis "<li>$box$inner</li>\n"
                    } elseif {$inner eq ""} {
                        append lis "<li>$box</li>\n"
                    } else {
                        if {$box ne "" && [string match <p>* $inner]} {
                            set inner "<p>$box[string range $inner 3 end]"
                        } elseif {$box ne ""} {
                            set inner "$box$inner"
                        }
                        append lis "<li>\n$inner\n</li>\n"
                    }
                }
                lappend out "<$tag$attr>\n$lis</$tag>"
            }
            table {
                lassign $b - al head rows
                set r "<table>\n<thead>\n<tr>\n"
                foreach c $head a $al {
                    append r "<th[_alignAttr $a]>[_inline $c]</th>\n"
                }
                append r "</tr>\n</thead>"
                if {[llength $rows]} {
                    append r "\n<tbody>\n"
                    foreach row $rows {
                        append r "<tr>\n"
                        foreach c $row a $al {
                            append r "<td[_alignAttr $a]>[_inline $c]</td>\n"
                        }
                        append r "</tr>\n"
                    }
                    append r "</tbody>"
                }
                lappend out "$r\n</table>"
            }
        }
    }
    return [join $out \n]
}

proc ::tclutils::tumd::_alignAttr {a} {
    expr {$a eq "" ? "" : " style=\"text-align:$a\""}
}

# ---- public API ---------------------------------------------------------------

# Split off YAML front matter. Returns {frontmatterText body}. If the document
# does not start with a "---" line that has a matching closing "---", the
# front matter is "" and body is the input unchanged.
proc ::tclutils::tumd::frontmatter {markdown} {
    set lines [split $markdown \n]
    if {[string trim [lindex $lines 0]] ne "---"} {
        return [list "" $markdown]
    }
    set fm {}
    set i 1
    set n [llength $lines]
    while {$i < $n && [string trim [lindex $lines $i]] ne "---"} {
        lappend fm [lindex $lines $i]
        incr i
    }
    if {$i >= $n} {
        return [list "" $markdown]
    }
    set body [join [lrange $lines [expr {$i + 1}] end] \n]
    return [list [join $fm \n] $body]
}

# Heading ids (unique in document order) and footnote numbers (in the order
# of the definitions; a repeated label is dropped, number 0).
proc ::tclutils::tumd::_number {blocks} {
    variable seen
    variable notes
    set out {}
    foreach b $blocks {
        switch -- [lindex $b 0] {
            h {
                lappend b [_uniqueSlug seen [lindex $b 2]]
            }
            quote {
                lset b 1 [_number [lindex $b 1]]
            }
            list {
                set items {}
                foreach it [lindex $b 4] {
                    lassign $it task ib
                    lappend items [list $task [_number $ib]]
                }
                lset b 4 $items
            }
            footnote {
                set key [lindex $b 1]
                if {![dict exists $notes $key]} {
                    dict set notes $key [expr {[dict size $notes] + 1}]
                    lset b 2 [dict get $notes $key]
                }
                lset b 3 [_number [lindex $b 3]]
            }
        }
        lappend out $b
    }
    return $out
}

# The footnote blocks of BLOCKS, at any depth: {number blocks ...}.
proc ::tclutils::tumd::_notes {blocks} {
    set out {}
    foreach b $blocks {
        switch -- [lindex $b 0] {
            quote {
                lappend out {*}[_notes [lindex $b 1]]
            }
            list {
                foreach it [lindex $b 4] {
                    lappend out {*}[_notes [lindex $it 1]]
                }
            }
            footnote {
                if {[lindex $b 2]} {
                    lappend out [lindex $b 2] [lindex $b 3]
                }
                lappend out {*}[_notes [lindex $b 3]]
            }
        }
    }
    return $out
}

# Blocks of a document for toHtml, headings and toc; leaves the link
# definitions and footnotes in the namespace for the rendering.
proc ::tclutils::tumd::_document {markdown {posVar ""} {defsVar ""} {offVar ""}} {
    variable refs
    variable seen
    variable notes
    variable noteRefs
    set refs {}
    set seen {}
    set notes {}
    set noteRefs {}
    set markdown [string map {\r\n \n \r \n} $markdown]
    lassign [frontmatter $markdown] fm body
    if {$offVar ne ""} {
        upvar 1 $offVar off
        set off [expr {$body eq $markdown ? 0
            : [llength [split $markdown \n]] - [llength [split $body \n]]}]
    }
    if {$posVar ne ""} {
        upvar 1 $posVar pos
        upvar 1 $defsVar defs
        return [_number [_parse [split $body \n] "" pos defs]]
    }
    return [_number [_parse [split $body \n]]]
}

# Parse a document: front matter dropped, CRLF and CR read as LF. Returns a
# dict: blocks (see _parse; heading ids and footnote numbers filled in),
# refs (link definitions) and notes (footnote numbers), for inline and
# paragraph. With -lines 1 also: lines ({first last} per top-level block,
# counted from 1 after the front matter), definitions ({key first last} per
# link definition) and offset (lines of the front matter).
proc ::tclutils::tumd::parse {markdown args} {
    variable refs
    variable notes
    set o [dict create -lines 0]
    foreach {k v} $args {
        if {![dict exists $o $k]} {
            return -code error -errorcode [list TCLUTILS TUMD OPTION $k] \
                "unknown option \"$k\", must be -lines"
        }
        dict set o $k $v
    }
    if {[dict get $o -lines]} {
        set blocks [_document $markdown pos defs off]
        set d [dict create blocks $blocks refs $refs notes $notes \
            lines $pos definitions $defs offset $off]
    } else {
        set blocks [_document $markdown]
        set d [dict create blocks $blocks refs $refs notes $notes]
    }
    set refs {}
    set notes {}
    return $d
}

# Run SCRIPT (in this namespace) with the link definitions R and the
# footnotes N of one document.
proc ::tclutils::tumd::_with {r n script} {
    variable refs
    variable notes
    variable noteRefs
    set saved [list $refs $notes $noteRefs]
    set refs $r
    set notes $n
    set noteRefs {}
    try {
        return [namespace eval ::tclutils::tumd $script]
    } finally {
        lassign $saved refs notes noteRefs
    }
}

# The HTML of the inline Markdown TEXT. REFS and NOTES are the link
# definitions and footnotes of the document (from parse).
proc ::tclutils::tumd::inline {text {refs {}} {notes {}}} {
    _with $refs $notes [list _inline $text]
}

# The HTML of a paragraph given as its LINES: joined with newlines, hard
# breaks (two trailing spaces, a trailing backslash) as <br>.
proc ::tclutils::tumd::paragraph {lines {refs {}} {notes {}}} {
    _with $refs $notes [list _para $lines]
}

# Text of an HTML fragment as written by inline: the entities decoded (the
# caller removes the tags).
proc ::tclutils::tumd::unescape {html} {
    variable entities
    set out ""
    set pos 0
    set re {&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[A-Za-z][A-Za-z0-9]{1,31});}
    while {[regexp -start $pos -indices -- $re $html m e]} {
        lassign $m a b
        set name [string range $html {*}$e]
        append out [string range $html $pos [expr {$a - 1}]]
        if {[string match {#[xX]*} $name]} {
            set c [expr {"0x[string range $name 2 end]"}]
            append out [expr {$c > 0 && $c <= 0x10FFFF ? [format %c $c] : "\ufffd"}]
        } elseif {[string index $name 0] eq "#"} {
            scan [string range $name 1 end] %d c
            append out [expr {$c > 0 && $c <= 0x10FFFF ? [format %c $c] : "\ufffd"}]
        } elseif {[dict exists $entities $name]} {
            append out [dict get $entities $name]
        } else {
            append out [string range $html $a $b]
        }
        set pos [expr {$b + 1}]
    }
    append out [string range $html $pos end]
}

# List of {level text} pairs for the top-level ATX and setext headings.
proc ::tclutils::tumd::headings {markdown} {
    set result {}
    foreach b [_document $markdown] {
        if {[lindex $b 0] eq "h"} {
            lappend result [lrange $b 1 2]
        }
    }
    return $result
}

# Markdown table-of-contents (nested bullet list with anchor links).
proc ::tclutils::tumd::toc {markdown} {
    set out {}
    foreach b [_document $markdown] {
        if {[lindex $b 0] ne "h"} continue
        lassign $b - lvl text id
        set indent [string repeat "  " [expr {$lvl - 1}]]
        lappend out "$indent- \[$text\](#$id)"
    }
    return [join $out \n]
}

variable ::tclutils::tumd::css {body { font-family: sans-serif; max-width: 50em; margin: 2em auto; padding: 0 1em; line-height: 1.5; }
pre, code { font-family: monospace; background: #f4f4f4; }
pre { padding: .5em; overflow-x: auto; }
table { border-collapse: collapse; }
th, td { border: 1px solid #ccc; padding: .2em .5em; }
blockquote { border-left: 3px solid #ccc; margin-left: 0; padding-left: 1em; color: #555; }
.footnotes { font-size: .9em; border-top: 1px solid #ccc; }}

# Convert Markdown to an HTML fragment (no <html> wrapper), or with -page 1 to
# a complete page. Front matter, if present, is dropped.
#   -page bool          complete HTML page (doctype, head, style, body)
#   -title text         page title (default: front matter title:, else the
#                       first heading)
#   -css text           style sheet of the page (default: a small one)
#   -lang code          lang attribute of the page
#   -linkmap {from to}  suffix pairs for relative links, e.g. {.md .html}
#   -headingoffset n    add n to every heading level (at most 6)
proc ::tclutils::tumd::toHtml {markdown args} {
    variable linkmap
    variable hoff
    variable css
    set o [dict create -page 0 -title "" -css $css -lang "" -linkmap {} -headingoffset 0]
    if {[llength $args] % 2} {
        return -code error -errorcode [list TCLUTILS TUMD OPTION [lindex $args end]] \
            "missing value for option \"[lindex $args end]\""
    }
    foreach {k v} $args {
        if {![dict exists $o $k]} {
            return -code error -errorcode [list TCLUTILS TUMD OPTION $k] \
                "unknown option \"$k\", must be [join [dict keys $o] {, }]"
        }
        dict set o $k $v
    }
    if {![string is integer -strict [dict get $o -headingoffset]]
            || ![string is boolean -strict [dict get $o -page]]
            || [llength [dict get $o -linkmap]] % 2} {
        return -code error -errorcode {TCLUTILS TUMD VALUE} \
            "-page needs a boolean, -headingoffset an integer, -linkmap pairs"
    }
    set linkmap [dict get $o -linkmap]
    set hoff [dict get $o -headingoffset]
    try {
        set blocks [_document $markdown]
        set html [_render $blocks 0]
        set fn [_notes $blocks]
        if {[llength $fn]} {
            append html "\n<section class=\"footnotes\">\n<ol>\n"
            foreach {n ib} $fn {
                set back " <a href=\"#fnref-$n\" class=\"footnote-backref\">\u21a9</a>"
                append html "<li id=\"fn-$n\">[_render $ib 1]$back</li>\n"
            }
            append html "</ol>\n</section>"
        }
        set title [dict get $o -title]
        if {[dict get $o -page] && $title eq ""} {
            lassign [frontmatter [string map {\r\n \n \r \n} $markdown]] fm
            if {[regexp -line {^title:[ \t]*(.*?)[ \t]*$} $fm -> t]} {
                set title [string trim $t "\"'"]
            } else {
                foreach b $blocks {
                    if {[lindex $b 0] eq "h"} {
                        regsub -all {<[^>]*>} [_inline [lindex $b 2]] "" t
                        set title [unescape $t]
                        break
                    }
                }
            }
        }
    } finally {
        set linkmap {}
        set hoff 0
    }
    if {![dict get $o -page]} {
        return $html
    }
    set lang [dict get $o -lang]
    set la [expr {$lang eq "" ? "" : " lang=\"[_escape $lang]\""}]
    set st [dict get $o -css]
    set style [expr {$st eq "" ? "" : "<style>\n$st\n</style>\n"}]
    return "<!DOCTYPE html>\n<html$la>\n<head>\n<meta charset=\"utf-8\">\n<title>[_escape $title]</title>\n$style</head>\n<body>\n$html\n</body>\n</html>"
}

package provide tclutils::tumd 0.3
