# tclutils::tuxml -- small XML text helper in pure Tcl
# Tcl 8.6+
#
# Scope of 0.1:
#   escape/unescape XML text and build simple tags/elements.  This module is
#   not a validating XML parser; it is a dependency-free writer/helper layer.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuxml {
    namespace export escape unescape declaration attrs tag element textElement
    variable version 0.1
}

proc ::tclutils::tuxml::escape {text args} {
    set opts [::tclutils::common::parseOptions [dict create -quotes 0] {*}$args]
    set quoteMode [::tclutils::common::ensureBoolean [dict get $opts -quotes] -quotes]
    set map [list & &amp\; < &lt\; > &gt\;]
    if {$quoteMode} {
        lappend map \" &quot\; ' &apos\;
    }
    return [string map $map $text]
}

proc ::tclutils::tuxml::unescape {text} {
    # Handle predefined entities and numeric character references.
    set text [string map [list &lt\; < &gt\; > &quot\; \" &apos\; ' &amp\; &] $text]
    set out ""
    set pos 0
    while {[regexp -indices -start $pos {&#(x[0-9A-Fa-f]+|[0-9]+);} $text m v]} {
        lassign $m a b
        lassign $v va vb
        append out [string range $text $pos [expr {$a - 1}]]
        set raw [string range $text $va $vb]
        if {[string index $raw 0] eq "x"} {
            scan [string range $raw 1 end] %x code
        } else {
            scan $raw %d code
        }
        append out [format %c $code]
        set pos [expr {$b + 1}]
    }
    append out [string range $text $pos end]
    return $out
}

proc ::tclutils::tuxml::declaration {{encoding UTF-8}} {
    return "<?xml version=\"1.0\" encoding=\"[escape $encoding -quotes 1]\"?>"
}

proc ::tclutils::tuxml::attrs {attributes} {
    set out ""
    dict for {name value} $attributes {
        if {![regexp {^[A-Za-z_][A-Za-z0-9_.:-]*$} $name]} {
            return -code error -errorcode [list TCLUTILS TUXML ATTR $name] "invalid XML attribute name: $name"
        }
        append out " " $name "=\"" [escape $value -quotes 1] "\""
    }
    return $out
}

proc ::tclutils::tuxml::CheckName {name what} {
    if {![regexp {^[A-Za-z_][A-Za-z0-9_.:-]*$} $name]} {
        return -code error -errorcode [list TCLUTILS TUXML NAME $name] "invalid XML $what name: $name"
    }
    return $name
}

proc ::tclutils::tuxml::tag {name {attributes {}}} {
    CheckName $name element
    return "<$name[attrs $attributes]/>"
}

proc ::tclutils::tuxml::element {name attributes content} {
    CheckName $name element
    return "<$name[attrs $attributes]>$content</$name>"
}

proc ::tclutils::tuxml::textElement {name attributes text} {
    return [element $name $attributes [escape $text]]
}

package provide tclutils::tuxml 0.1
