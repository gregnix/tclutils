# tclutils::tubookmark -- read and write the Netscape bookmark file format,
# Description: read and write the Netscape bookmark file format used by browsers for import/export
# Category: Data · structures & formats
# the de-facto interchange format browsers use to import/export bookmarks.
# Pure Tcl; entity (un)escaping reuses tclutils::tuxml. Tcl 8.6+ and 9.x.
#
# A bookmark is a dict: {title url folder folders tags adddate}. "folders" is
# the list of folder names from the top ({} = top level); "folder" is the
# same joined with "/" for display (ambiguous when a name holds "/").
# serialize uses "folders" when present, else splits "folder" at "/".
# "tags" is a list. Attribute values may be in double or single quotes or
# unquoted. serialize keeps the order of folders and links as given (0.3;
# 0.2 sorted the folders and put them before the links).
# Optional keys (only present when the file has them): "description", the
# <DD> text after a link; "toolbar", the folders path of the folder marked
# PERSONAL_TOOLBAR_FOLDER that holds the bookmark. serialize writes both
# back.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tuxml 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tubookmark {
    namespace export parse serialize
    variable version 0.3
}

proc ::tclutils::tubookmark::_folders {stack} {
    set parts {}
    foreach f $stack { if {$f ne ""} { lappend parts $f } }
    return $parts
}

# Value of attribute name in an attribute string: "..." or '...' or bare
proc ::tclutils::tubookmark::_attrVal {attrs name} {
    if {[regexp -nocase "\\y${name}\\s*=\\s*(?:\"(\[^\"\]*)\"|'(\[^'\]*)'|(\[^\\s>\"'\]+))" \
            $attrs -> a b c]} {
        return "$a$b$c"
    }
    return ""
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
    set pendingBar 0
    set bars {}
    set toolbar {}
    set last ""
    set reH3 "<h3\\y(\[^>\]*)>[_upTo h3]"
    set reA  "<a\\s+(\[^>\]*)>[_upTo a]"
    set reDD "<dd\\y\[^>\]*>(\[^<\]*)"
    set re   "$reH3|<dl\\y\[^>\]*>|</dl\\s*>|$reA|$reDD"
    set pos 0
    while {[regexp -nocase -indices -start $pos $re $html m]} {
        set tok [string range $html {*}$m]
        set pos [expr {[lindex $m 1] + 1}]
        if {[regexp -nocase "^$reH3" $tok -> h3attrs name]} {
            set pending [::tclutils::tuxml::unescape $name]
            set pendingBar [string equal -nocase \
                [_attrVal $h3attrs personal_toolbar_folder] true]
            set last ""
        } elseif {[regexp -nocase {^<dl} $tok]} {
            lappend stack $pending
            lappend bars $pendingBar
            if {$pendingBar && ![llength $toolbar]} { set toolbar [_folders $stack] }
            set pending ""
            set pendingBar 0
            set last ""
        } elseif {[regexp -nocase {^</dl} $tok]} {
            if {[llength $stack]} {
                set stack [lrange $stack 0 end-1]
                set bars [lrange $bars 0 end-1]
                if {[lsearch -exact $bars 1] < 0} { set toolbar {} }
            }
            set last ""
        } elseif {[regexp -nocase "^$reDD" $tok -> dd]} {
            # a description belongs to the link right before it
            set dd [string trim [::tclutils::tuxml::unescape $dd]]
            if {$last ne "" && $dd ne ""} {
                lset out $last [dict replace [lindex $out $last] description $dd]
            }
            set last ""
        } elseif {[regexp -nocase "^$reA" $tok -> attrs title]} {
            set href [_attrVal $attrs href]
            set tagstr [_attrVal $attrs tags]
            set add [_attrVal $attrs add_date]
            set tags {}
            foreach t [split [::tclutils::tuxml::unescape $tagstr] ,] {
                set t [string trim $t]
                if {$t ne ""} { lappend tags $t }
            }
            set bm [dict create \
                title [::tclutils::tuxml::unescape $title] \
                url [::tclutils::tuxml::unescape $href] \
                folder [join [_folders $stack] /] \
                folders [_folders $stack] \
                tags $tags \
                adddate [::tclutils::tuxml::unescape $add]]
            if {[llength $toolbar]} { dict set bm toolbar $toolbar }
            lappend out $bm
            set last [expr {[llength $out] - 1}]
        }
    }
    return $out
}

# Serialize a list of bookmark dicts into Netscape bookmark HTML.
# Option: -title (document title, default "Bookmarks").
proc ::tclutils::tubookmark::serialize {bookmarks args} {
    set opts [::tclutils::common::parseOptions {-title Bookmarks} {*}$args]
    set title [dict get $opts -title]

    # tree of nodes {children {name node ...} seq {{F name} {I bm} ...}};
    # seq keeps folders and links in the order they first appear
    set root [dict create children {} seq {}]
    set bars {}
    foreach bm $bookmarks {
        set tb [_get $bm toolbar]
        if {[llength $tb] && [lsearch -exact $bars $tb] < 0} { lappend bars $tb }
        if {[dict exists $bm folders]} {
            set parts [dict get $bm folders]
        } else {
            set parts {}
            foreach p [split [_get $bm folder] /] { if {$p ne ""} { lappend parts $p } }
        }
        set keypath {}
        foreach p $parts {
            if {![dict exists $root {*}$keypath children $p]} {
                set seq [dict get $root {*}$keypath seq]
                lappend seq [list F $p]
                dict set root {*}$keypath seq $seq
                dict set root {*}$keypath children $p [dict create children {} seq {}]
            }
            lappend keypath children $p
        }
        set seq [dict get $root {*}$keypath seq]
        lappend seq [list I $bm]
        dict set root {*}$keypath seq $seq
    }
    set body [_emit $root "    " {} $bars]
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

proc ::tclutils::tubookmark::_emit {node indent path bars} {
    set s ""
    foreach entry [dict get $node seq] {
        lassign $entry kind v
        if {$kind eq "F"} {
            set sub [linsert $path end $v]
            set h3 "<H3"
            if {[lsearch -exact $bars $sub] >= 0} {
                append h3 { PERSONAL_TOOLBAR_FOLDER="true"}
            }
            append s "$indent<DT>$h3>[::tclutils::tuxml::escape $v]</H3>\n"
            append s "$indent<DL><p>\n"
            append s [_emit [dict get $node children $v] "$indent    " $sub $bars]
            append s "$indent</DL><p>\n"
        } else {
            set bm $v
            set attrs "HREF=\"[_attr [_get $bm url]]\""
            set tags [_get $bm tags]
            if {$tags ne ""} { append attrs " TAGS=\"[_attr [join $tags ,]]\"" }
            set add [_get $bm adddate]
            if {$add ne ""} { append attrs " ADD_DATE=\"[_attr $add]\"" }
            append s "$indent<DT><A $attrs>[::tclutils::tuxml::escape [_get $bm title]]</A>\n"
            set dd [_get $bm description]
            if {$dd ne ""} { append s "$indent<DD>[::tclutils::tuxml::escape $dd]\n" }
        }
    }
    return $s
}

package provide tclutils::tubookmark 0.3
