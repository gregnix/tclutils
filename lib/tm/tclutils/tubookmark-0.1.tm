# tclutils::tubookmark -- read and write the Netscape bookmark file format,
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
    variable version 0.1
}

proc ::tclutils::tubookmark::_path {stack} {
    set parts {}
    foreach f $stack { if {$f ne ""} { lappend parts $f } }
    return [join $parts /]
}

# Parse Netscape bookmark HTML into a flat list of bookmark dicts.
proc ::tclutils::tubookmark::parse {html} {
    set out {}
    set stack {}
    set pending ""
    foreach line [split $html \n] {
        set line [string trim $line]
        if {[regexp -nocase {<h3[^>]*>(.*?)</h3>} $line -> name]} {
            set pending [::tclutils::tuxml::unescape $name]
            continue
        }
        if {[regexp -nocase {<dl[ >]} $line]} {
            lappend stack $pending
            set pending ""
            continue
        }
        if {[regexp -nocase {</dl>} $line]} {
            if {[llength $stack]} { set stack [lrange $stack 0 end-1] }
            continue
        }
        if {[regexp -nocase {<a\s+([^>]*)>(.*?)</a>} $line -> attrs title]} {
            set href ""
            regexp -nocase {href="([^"]*)"} $attrs -> href
            set tagstr ""
            regexp -nocase {tags="([^"]*)"} $attrs -> tagstr
            set add ""
            regexp -nocase {add_date="([^"]*)"} $attrs -> add
            set tags {}
            foreach t [split $tagstr ,] {
                set t [string trim $t]
                if {$t ne ""} { lappend tags $t }
            }
            lappend out [dict create \
                title [::tclutils::tuxml::unescape $title] \
                url [::tclutils::tuxml::unescape $href] \
                folder [_path $stack] \
                tags $tags \
                adddate $add]
            continue
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
    return "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n\
<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n\
<TITLE>$t</TITLE>\n<H1>$t</H1>\n<DL><p>\n$body</DL><p>\n"
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
            set attrs "HREF=\"[::tclutils::tuxml::escape [_get $bm url]]\""
            set tags [_get $bm tags]
            if {$tags ne ""} { append attrs " TAGS=\"[join $tags ,]\"" }
            set add [_get $bm adddate]
            if {$add ne ""} { append attrs " ADD_DATE=\"$add\"" }
            append s "$indent<DT><A $attrs>[::tclutils::tuxml::escape [_get $bm title]]</A>\n"
        }
    }
    return $s
}

package provide tclutils::tubookmark 0.1
