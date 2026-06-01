# tclutils::tumd -- minimal Markdown helpers (CommonMark subset)
# Tcl 8.6+
#
# A focused, dependency-free Markdown utility: convert a CommonMark subset to
# HTML, extract ATX headings, build a table-of-contents, and split off YAML
# front matter. It is intentionally small -- for the full pipeline (AST, PDF,
# Tk viewer, GFM tables, nested lists) use the mdstack/docir stack.
#
# Supported blocks: ATX headings, paragraphs, fenced code (``` / ~~~),
# blockquotes, flat ordered/unordered lists, horizontal rules.
# Supported inline: code spans, **bold**/__bold__, *italic*/_italic_,
# [text](url) links, ![alt](url) images, <autolinks>, and hard line breaks
# (two trailing spaces).
# Not handled (by design): nested lists, setext headings, GFM tables,
# reference-style links, raw-HTML passthrough.

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tumd {
    namespace export toHtml headings toc frontmatter
    variable version 0.1
}

proc ::tclutils::tumd::_escape {s} {
    return [string map {& &amp; < &lt; > &gt; \" &quot;} $s]
}

# GitHub-style heading slug.
proc ::tclutils::tumd::_slug {text} {
    set s [string tolower $text]
    regsub -all {[*_`]} $s "" s
    regsub -all {[^a-z0-9 -]} $s "" s
    regsub -all {[ ]+} $s "-" s
    return $s
}

# Convert inline Markdown in one logical line to HTML.
proc ::tclutils::tumd::_inline {s} {
    # 1. Protect code spans before escaping or other inline processing.
    set codes {}
    while {[regexp -indices {`([^`]+)`} $s m sub]} {
        set content [string range $s [lindex $sub 0] [lindex $sub 1]]
        set ph "\x00C[llength $codes]\x00"
        lappend codes "<code>[_escape $content]</code>"
        set s [string replace $s [lindex $m 0] [lindex $m 1] $ph]
    }
    # 2. Escape HTML in the remaining text.
    set s [_escape $s]
    # 3. Images, then links (image syntax contains link syntax).
    regsub -all {!\[([^\]]*)\]\(([^)]+)\)} $s {<img src="\2" alt="\1">} s
    regsub -all {\[([^\]]*)\]\(([^)]+)\)} $s {<a href="\2">\1</a>} s
    # 4. Autolinks (the < > were escaped in step 2).
    regsub -all {&lt;(https?://[^&]+)&gt;} $s {<a href="\1">\1</a>} s
    # 5. Bold before italic so ** is not consumed by *.
    regsub -all {\*\*([^*]+)\*\*} $s {<strong>\1</strong>} s
    regsub -all {__([^_]+)__} $s {<strong>\1</strong>} s
    regsub -all {\*([^*]+)\*} $s {<em>\1</em>} s
    regsub -all {(^|[^\w])_([^_]+)_(?=[^\w]|$)} $s {\1<em>\2</em>} s
    # 6. Restore code spans.
    set idx 0
    foreach c $codes {
        set s [string map [list "\x00C$idx\x00" $c] $s]
        incr idx
    }
    return $s
}

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

# List of {level text} pairs for ATX headings (skipping fenced code).
proc ::tclutils::tumd::headings {markdown} {
    lassign [frontmatter $markdown] fm body
    set result {}
    set inFence 0
    foreach line [split $body \n] {
        if {[regexp {^(```+|~~~+)} $line]} {
            set inFence [expr {!$inFence}]
            continue
        }
        if {$inFence} continue
        if {[regexp {^(#{1,6})[ \t]+(.*)$} $line -> h t]} {
            regsub {[ \t]+#+[ \t]*$} $t "" t
            lappend result [list [string length $h] [string trim $t]]
        }
    }
    return $result
}

# Markdown table-of-contents (nested bullet list with anchor links).
proc ::tclutils::tumd::toc {markdown} {
    set out {}
    foreach hd [headings $markdown] {
        lassign $hd lvl text
        set indent [string repeat "  " [expr {$lvl - 1}]]
        lappend out "$indent- \[$text\](#[_slug $text])"
    }
    return [join $out \n]
}

# Convert a CommonMark subset to an HTML fragment (no <html> wrapper).
# Front matter, if present, is dropped.
proc ::tclutils::tumd::toHtml {markdown} {
    lassign [frontmatter $markdown] fm body
    set lines [split $body \n]
    set n [llength $lines]
    set html {}
    set i 0
    while {$i < $n} {
        set line [lindex $lines $i]

        # Fenced code block.
        if {[regexp {^[ ]{0,3}(```+|~~~+)[ \t]*(\S*)[ \t]*$} $line -> fence lang]} {
            set fenceChar [string index $fence 0]
            set code {}
            incr i
            while {$i < $n && \
                    ![regexp "^\[ \]{0,3}\\${fenceChar}{3,}\[ \t\]*$" [lindex $lines $i]]} {
                lappend code [lindex $lines $i]
                incr i
            }
            incr i
            set cls ""
            if {$lang ne ""} { set cls " class=\"language-[_escape $lang]\"" }
            lappend html "<pre><code$cls>[_escape [join $code \n]]</code></pre>"
            continue
        }

        # Blank line.
        if {[string trim $line] eq ""} { incr i; continue }

        # ATX heading.
        if {[regexp {^(#{1,6})[ \t]+(.*)$} $line -> hashes htext]} {
            regsub {[ \t]+#+[ \t]*$} $htext "" htext
            set lvl [string length $hashes]
            lappend html "<h$lvl id=\"[_slug $htext]\">[_inline [string trim $htext]]</h$lvl>"
            incr i
            continue
        }

        # Horizontal rule.
        if {[regexp {^[ ]{0,3}([-*_])[ ]*(\1[ ]*){2,}$} $line]} {
            lappend html "<hr>"
            incr i
            continue
        }

        # Blockquote (collect contiguous > lines, render inner recursively).
        if {[regexp {^[ ]{0,3}>} $line]} {
            set q {}
            while {$i < $n && [regexp {^[ ]{0,3}>} [lindex $lines $i]]} {
                set l [lindex $lines $i]
                regsub {^[ ]{0,3}>[ ]?} $l "" l
                lappend q $l
                incr i
            }
            lappend html "<blockquote>\n[toHtml [join $q \n]]\n</blockquote>"
            continue
        }

        # Flat list (ordered or unordered).
        if {[regexp {^[ ]{0,3}([-*+]|\d+[.)])[ \t]+} $line]} {
            set ordered [regexp {^[ ]{0,3}\d} $line]
            set tag [expr {$ordered ? "ol" : "ul"}]
            set lis ""
            while {$i < $n && \
                    [regexp {^[ ]{0,3}(?:[-*+]|\d+[.)])[ \t]+(.*)$} [lindex $lines $i] -> itext]} {
                append lis "<li>[_inline [string trim $itext]]</li>\n"
                incr i
            }
            lappend html "<$tag>\n$lis</$tag>"
            continue
        }

        # Paragraph: gather until a blank line or a new block start.
        set para {}
        while {$i < $n && [string trim [lindex $lines $i]] ne "" && \
                ![regexp {^[ ]{0,3}(```+|~~~+|#{1,6}[ \t]|>|(?:[-*+]|\d+[.)])[ \t])} \
                    [lindex $lines $i]]} {
            lappend para [lindex $lines $i]
            incr i
        }
        set ptext ""
        foreach pl $para {
            if {[regexp {  +$} $pl]} {
                append ptext "[_inline [string trim $pl]]<br>\n"
            } else {
                append ptext "[_inline [string trim $pl]]\n"
            }
        }
        lappend html "<p>[string trim $ptext]</p>"
    }
    return [join $html \n]
}

package provide tclutils::tumd 0.1
