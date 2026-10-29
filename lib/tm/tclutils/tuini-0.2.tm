# tclutils::tuini -- INI file reader/writer
# Description: INI file reader/writer
# Category: Data · structures & formats
#
# Parses INI text into a dict section -> (dict key -> value) and serializes it
# back. Keys before any [section] live in the global section "". Section and key
# order is preserved (Tcl dicts keep insertion order), so a parse/toIni round
# trip keeps the structure. Comments (lines starting with ; or #) are dropped.
# When a key occurs twice in a section, the last value wins (the Windows
# profile API takes the first). Blanks around keys and values are dropped.
#
# 0.2: setValue, addSection and toIni refuse what INI cannot hold, so toIni
# never writes text that parse cannot read back: a line break in a value; in
# a key "=", a line break, a leading ";", "#" or "[", blanks at either end;
# in a section name "]", a line break, blanks at either end. Error code
# {TCLUTILS TUINI VALUE}. Blanks at the ends of a value are still dropped.

package require Tcl 8.6-

namespace eval ::tclutils {}
namespace eval ::tclutils::tuini {
    namespace export parse toIni sections keys get has setValue \
        removeKey addSection removeSection
}

# Parse INI text -> dict section -> (dict key -> value).
proc ::tclutils::tuini::parse {ini} {
    set data [dict create]
    set section ""
    set norm [string map [list "\r\n" "\n" "\r" "\n"] $ini]
    foreach raw [split $norm "\n"] {
        set line [string trim $raw]
        if {$line eq ""} continue
        if {[string index $line 0] in {";" "#"}} continue
        if {[string index $line 0] eq "\["} {
            set close [string first "\]" $line]
            if {$close < 0} {
                return -code error -errorcode {TCLUTILS TUINI SYNTAX} \
                    "unterminated section header: $line"
            }
            set section [string trim [string range $line 1 [expr {$close - 1}]]]
            if {![dict exists $data $section]} {
                dict set data $section [dict create]
            }
            continue
        }
        set eq [string first "=" $line]
        if {$eq < 0} {
            return -code error -errorcode {TCLUTILS TUINI SYNTAX} \
                "line without '=' : $line"
        }
        set key [string trim [string range $line 0 [expr {$eq - 1}]]]
        set val [string trim [string range $line [expr {$eq + 1}] end]]
        dict set data $section $key $val
    }
    if {[dict exists $data ""] && [dict size [dict get $data ""]] == 0} {
        dict unset data ""
    }
    return $data
}

# Check that section/key/value can be written as INI and read back.
proc ::tclutils::tuini::_checkSection {section} {
    if {[regexp {[\]\n\r]} $section] || [string trim $section] ne $section} {
        return -code error -errorcode {TCLUTILS TUINI VALUE} \
            "section \"$section\" cannot be written as INI"
    }
}
proc ::tclutils::tuini::_checkKey {section key} {
    if {[regexp {[=\n\r]} $key] || [string index $key 0] in {; # [}
            || [string trim $key] ne $key} {
        return -code error -errorcode {TCLUTILS TUINI VALUE} \
            "key \"$key\" in \[$section\] cannot be written as INI"
    }
}
proc ::tclutils::tuini::_checkValue {section key value} {
    if {[regexp {[\n\r]} $value]} {
        return -code error -errorcode {TCLUTILS TUINI VALUE} \
            "value of $section.$key: no line breaks in INI"
    }
}

# Serialize a data dict back to INI text. The global section "" is written first
# (without a header), then each named section.
proc ::tclutils::tuini::toIni {data} {
    dict for {section kv} $data {
        if {$section ne ""} { _checkSection $section }
        dict for {k v} $kv {
            _checkKey $section $k
            _checkValue $section $k $v
        }
    }
    set out {}
    if {[dict exists $data ""]} {
        dict for {k v} [dict get $data ""] { lappend out "$k=$v" }
    }
    dict for {section kv} $data {
        if {$section eq ""} continue
        if {[llength $out]} { lappend out "" }
        lappend out "\[$section\]"
        dict for {k v} $kv { lappend out "$k=$v" }
    }
    return [join $out "\n"]
}

# All section names (including "" if the global section has keys).
proc ::tclutils::tuini::sections {data} {
    return [dict keys $data]
}

# Keys of a section ({} if the section is absent).
proc ::tclutils::tuini::keys {data {section ""}} {
    if {![dict exists $data $section]} { return {} }
    return [dict keys [dict get $data $section]]
}

# Value of a key, or $default if absent.
proc ::tclutils::tuini::get {data section key {default ""}} {
    if {[dict exists $data $section $key]} {
        return [dict get $data $section $key]
    }
    return $default
}

proc ::tclutils::tuini::has {data section key} {
    return [dict exists $data $section $key]
}

# Return a copy of data with section/key set to value.
proc ::tclutils::tuini::setValue {data section key value} {
    if {$section ne ""} { _checkSection $section }
    _checkKey $section $key
    _checkValue $section $key $value
    dict set data $section $key $value
    return $data
}

# Return a copy of data with a key removed from a section.
proc ::tclutils::tuini::removeKey {data section key} {
    if {[dict exists $data $section $key]} {
        dict unset data $section $key
    }
    return $data
}

# Return a copy of data with an (empty) section ensured to exist.
proc ::tclutils::tuini::addSection {data section} {
    if {$section ne ""} { _checkSection $section }
    if {![dict exists $data $section]} {
        dict set data $section [dict create]
    }
    return $data
}

# Return a copy of data with a whole section removed.
proc ::tclutils::tuini::removeSection {data section} {
    if {[dict exists $data $section]} {
        dict unset data $section
    }
    return $data
}

package provide tclutils::tuini 0.2
