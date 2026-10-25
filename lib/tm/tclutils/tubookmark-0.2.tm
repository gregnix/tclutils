# tclutils::tubookmark -- read and write the Netscape bookmark file format,
# Description: read and write the Netscape bookmark file format used by browsers for import/export
# Category: Data · structures & formats
# the de-facto interchange format browsers use to import/export bookmarks.
# Pure Tcl; entity (un)escaping reuses tclutils::tuxml. Tcl 8.6+ and 9.x.
#
# A bookmark is a dict: {title url folder tags adddate}. "folder" is a "/"-joined
# path ("" = top level); "tags" is a list.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tuxml 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tubookmark {
    namespace export parse serialize
    variable version 0.2
}

proc ::tclutils::tubookmark::_path {stack} {
    set parts {}
    foreach f $stack { if {$f ne ""} { lappend parts $f } }
    return [join $parts /]
}

# Text up to the closing tag: no "<" unless it starts something other than
# the close tag. (A lazy ".*?" would not help: in a Tcl ARE the first
# quantifier sets the greediness of the whole expression.)
proc ::tclutils::tubookmark::_upTo {tag} {
    return "((?:\[^<\]|<(?!/${tag}>))*)</${tag}>"
}

# Parse Netscape bookmark HTML into a flat list of bookmark dicts.
# The document is read tag by tag, not line by line: every <A> is its own
# bookmark, also when a line holds several, and <H3>/<DL> may share a line
# with links.
proc ::tclutils::tubookmark::parse {html} {
    set out {}
    set stack {}
    set pending ""
    set reH3 "<h3\\y\[^>\]*>[_upTo h3]"
    set reA  "<a\\s+(\[^>\]*)>[_upTo a]"
    set re   "$reH3|<dl\\y\[^>\]*>|</dl\\s*>|$reA"
    set pos 0
    while {[regexp -nocase -indices -start $pos $re $html m]} {
        set tok [string range $html {*}$m]
        set pos [expr {[lindex $m 1] + 1}]
        if {[regexp -nocase "^$reH3" $tok -> name]} {
            set pending [::tclutils::tuxml::unescape $name]
        } elseif {[regexp -nocase {^<dl} $tok]} {
            lappend stack $pending
            set pending ""
        } elseif {[regexp -nocase {^</dl} $tok]} {
            if {[llength $stack]} { set stack [lrange $stack 0 end-1] }
        } elseif {[regexp -nocase "^$reA" $tok -> attrs title]} {
            set href ""
            regexp -nocase {\yhref="([^"]*)"} $attrs -> href
            set tagstr ""
            regexp -nocase {\ytags="([^"]*)"} $attrs -> tagstr
            set add ""
            regexp -nocase {\yadd_date="([^"]*)"} $attrs -> add
            set tags {}
            foreach t [split [::tclutils::tuxml::unescape $tagstr] ,] {
                set t [string trim $t]
                if {$t ne ""} { lappend tags $t }
            }
            lappend out [dict create \
                title [::tclutils::tuxml::unescape $title] \
                url [::tclutils::tuxml::unescape $href] \
                folder [_path $stack] \
                tags $tags \
                adddate [::tclutils::tuxml::unescape $add]]
        }
    }
    return $out
}

# Serialize a list of bookmark dicts into Netscape bookmark HTML.
# Option: -title (document title, default "Bookmarks").
proc ::tclutils::tubookmark::serialize {bookmarks args} {
    set opts [::tclutils::common::parseOptions {-title Bookmarks} {*}$args]
    set title [dict get $opts -title]

    set root [dict create]
    foreach bm $bookmarks {
        set parts {}
        foreach p [split [_get $bm folder] /] { if {$p ne ""} { lappend parts $p } }
        set keypath {}
        foreach p $parts { lappend keypath children $p }
        set itemsKey [concat $keypath items]
        set cur {}
        if {[dict exists $root {*}$itemsKey]} { set cur [dict get $root {*}$itemsKey] }
        lappend cur $bm
        dict set root {*}$itemsKey $cur
    }
    set body [_emit $root "    "]
    set t [::tclutils::tuxml::escape $title]
    set head [list \
        "<!DOCTYPE NETSCAPE-Bookmark-file-1>" \
        "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">" \
        "<TITLE>$t</TITLE>" \
        "<H1>$t</H1>" \
        "<DL><p>"]
    return "[join $head \n]\n$body</DL><p>\n"
}

# An attribute value: the text escapes plus the double quote.
proc ::tclutils::tubookmark::_attr {value} {
    return [string map [list \" &quot\;] [::tclutils::tuxml::escape $value]]
}

proc ::tclutils::tubookmark::_get {d k} {
    if {[dict exists $d $k]} { return [dict get $d $k] }
    return ""
}

proc ::tclutils::tubookmark::_emit {node indent} {
    set s ""
    if {[dict exists $node children]} {
        foreach name [lsort [dict keys [dict get $node children]]] {
            append s "$indent<DT><H3>[::tclutils::tuxml::escape $name]</H3>\n"
            append s "$indent<DL><p>\n"
            append s [_emit [dict get $node children $name] "$indent    "]
            append s "$indent</DL><p>\n"
        }
    }
    if {[dict exists $node items]} {
        foreach bm [dict get $node items] {
            set attrs "HREF=\"[_attr [_get $bm url]]\""
            set tags [_get $bm tags]
            if {$tags ne ""} { append attrs " TAGS=\"[_attr [join $tags ,]]\"" }
            set add [_get $bm adddate]
            if {$add ne ""} { append attrs " ADD_DATE=\"[_attr $add]\"" }
            append s "$indent<DT><A $attrs>[::tclutils::tuxml::escape [_get $bm title]]</A>\n"
        }
    }
    return $s
}

package provide tclutils::tubookmark 0.2
