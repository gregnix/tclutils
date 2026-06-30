# tclutils::tujson -- small JSON helper in pure Tcl
# Description: small JSON helper in pure Tcl
# Category: Data · structures & formats
# Tcl 8.6+
#
# Provides string quoting/escaping, minify/pretty formatting, validation,
# and a small dependency-free JSON parser that maps JSON objects to Tcl dicts
# and JSON arrays to Tcl lists.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tujson {
    namespace export escape quote minify pretty validate parse parseTyped fromJson filePretty fileMinify toJson str num bool null obj arr
    variable version 0.1
}

proc ::tclutils::tujson::escape {text} {
    set out ""
    set n [string length $text]
    for {set i 0} {$i < $n} {incr i} {
        set ch [string index $text $i]
        scan $ch %c code
        switch -- $ch {
            "\\" { append out "\\\\" }
            "\"" { append out "\\\"" }
            "\b" { append out "\\b" }
            "\f" { append out "\\f" }
            "\n" { append out "\\n" }
            "\r" { append out "\\r" }
            "\t" { append out "\\t" }
            default {
                if {$code < 0x20} {
                    append out [::format {\u%04x} $code]
                } else {
                    append out $ch
                }
            }
        }
    }
    return $out
}

proc ::tclutils::tujson::quote {text} {
    return "\"[escape $text]\""
}

proc ::tclutils::tujson::Classify {ch} {
    switch -- $ch {
        "\{" { return openObj }
        "[" { return openArr }
        "\}" { return closeObj }
        "]" { return closeArr }
        ":" { return colon }
        "," { return comma }
        default { return other }
    }
}

proc ::tclutils::tujson::MinifyCore {json {validateOnly 0}} {
    set out ""
    set stack {}
    set inString 0
    set escaped 0
    set n [string length $json]

    for {set i 0} {$i < $n} {incr i} {
        set ch [string index $json $i]
        if {$inString} {
            if {!$validateOnly} { append out $ch }
            if {$escaped} {
                set escaped 0
            } elseif {$ch eq "\\"} {
                set escaped 1
            } elseif {$ch eq "\""} {
                set inString 0
            }
            continue
        }

        if {[string is space $ch]} {
            continue
        }
        if {$ch eq "\""} {
            set inString 1
            if {!$validateOnly} { append out $ch }
            continue
        }

        switch -- [Classify $ch] {
            openObj { lappend stack "\}" }
            openArr { lappend stack "]" }
            closeObj - closeArr {
                if {[llength $stack] == 0 || [lindex $stack end] ne $ch} {
                    return -code error -errorcode {TCLUTILS TUJSON STRUCTURE} "JSON structure mismatch near offset $i"
                }
                set stack [lrange $stack 0 end-1]
            }
        }
        if {!$validateOnly} { append out $ch }
    }
    if {$inString} {
        return -code error -errorcode {TCLUTILS TUJSON STRING} "unterminated JSON string"
    }
    if {[llength $stack] > 0} {
        return -code error -errorcode {TCLUTILS TUJSON STRUCTURE} "unterminated JSON structure"
    }
    return $out
}

proc ::tclutils::tujson::minify {json} {
    # parse first so validation is semantic, not only bracket-balancing.
    parse $json
    return [MinifyCore $json 0]
}

proc ::tclutils::tujson::validate {json} {
    parse $json
    return 1
}

proc ::tclutils::tujson::pretty {json args} {
    set opts [::tclutils::common::parseOptions [dict create -indent "  "] {*}$args]
    set indentUnit [dict get $opts -indent]
    set json [minify $json]
    set out ""
    set level 0
    set inString 0
    set escaped 0
    set n [string length $json]

    for {set i 0} {$i < $n} {incr i} {
        set ch [string index $json $i]
        if {$inString} {
            append out $ch
            if {$escaped} {
                set escaped 0
            } elseif {$ch eq "\\"} {
                set escaped 1
            } elseif {$ch eq "\""} {
                set inString 0
            }
            continue
        }
        if {$ch eq "\""} {
            set inString 1
            append out $ch
            continue
        }
        switch -- $ch {
            "\{" - "[" {
                append out $ch "\n"
                incr level
                append out [string repeat $indentUnit $level]
            }
            "\}" - "]" {
                append out "\n"
                incr level -1
                append out [string repeat $indentUnit $level] $ch
            }
            "," {
                append out ",\n" [string repeat $indentUnit $level]
            }
            ":" {
                append out ": "
            }
            default {
                append out $ch
            }
        }
    }
    return $out
}

proc ::tclutils::tujson::parse {json} {
    set pos 0
    set result [_parseValue $json pos]
    _skipWs $json pos
    if {$pos != [string length $json]} {
        _fail $pos "unexpected trailing data"
    }
    return $result
}

proc ::tclutils::tujson::fromJson {json} {
    return [parse $json]
}

# parseTyped -- like parse, but preserves JSON type information so callers can
# tell objects, arrays and scalars apart (e.g. a tree viewer).
#
# Returns a typed node: a two-element list {type value} where
#   {object <dict>}   value is a dict mapping key -> typed node (insertion order)
#   {array  <list>}   value is a list of typed nodes
#   {string <s>}      value is the (unescaped) string
#   {number <n>}      value is the number in its source spelling
#   {boolean true|false}
#   {null {}}
proc ::tclutils::tujson::parseTyped {json} {
    set pos 0
    set result [_parseTypedValue $json pos]
    _skipWs $json pos
    if {$pos != [string length $json]} {
        _fail $pos "unexpected trailing data"
    }
    return $result
}

proc ::tclutils::tujson::_parseTypedValue {json posVar} {
    upvar 1 $posVar pos
    _skipWs $json pos
    set ch [_peek $json $pos]
    switch -- $ch {
        "\{" { return [_parseTypedObject $json pos] }
        "\[" { return [_parseTypedArray $json pos] }
        "\"" { return [::list string [_parseString $json pos]] }
        "t" { _parseLiteral $json pos true 1;  return [::list boolean true] }
        "f" { _parseLiteral $json pos false 0; return [::list boolean false] }
        "n" { _parseLiteral $json pos null "";  return [::list null {}] }
        "" { _fail $pos "unexpected end of input" }
        default {
            if {$ch eq "-" || [string is digit -strict $ch]} {
                return [::list number [_parseNumber $json pos]]
            }
            _fail $pos "unexpected character '$ch'"
        }
    }
}

proc ::tclutils::tujson::_parseTypedObject {json posVar} {
    upvar 1 $posVar pos
    set result [dict create]
    _expect $json pos "\{"
    _skipWs $json pos
    if {[_peek $json $pos] eq "\}"} {
        incr pos
        return [::list object $result]
    }
    while 1 {
        _skipWs $json pos
        if {[_peek $json $pos] ne "\""} {
            _fail $pos "expected object key string"
        }
        set key [_parseString $json pos]
        _skipWs $json pos
        _expect $json pos ":"
        dict set result $key [_parseTypedValue $json pos]
        _skipWs $json pos
        set ch [_peek $json $pos]
        if {$ch eq "\}"} {
            incr pos
            return [::list object $result]
        } elseif {$ch eq ","} {
            incr pos
            continue
        } else {
            _fail $pos "expected ',' or '\}'"
        }
    }
}

proc ::tclutils::tujson::_parseTypedArray {json posVar} {
    upvar 1 $posVar pos
    set result {}
    _expect $json pos "\["
    _skipWs $json pos
    if {[_peek $json $pos] eq "]"} {
        incr pos
        return [::list array $result]
    }
    while 1 {
        lappend result [_parseTypedValue $json pos]
        _skipWs $json pos
        set ch [_peek $json $pos]
        if {$ch eq "]"} {
            incr pos
            return [::list array $result]
        } elseif {$ch eq ","} {
            incr pos
            continue
        } else {
            _fail $pos "expected ',' or ']'"
        }
    }
}

proc ::tclutils::tujson::_fail {pos msg} {
    return -code error -errorcode [::list TCLUTILS TUJSON PARSE $pos] \
        "invalid JSON at offset $pos: $msg"
}

proc ::tclutils::tujson::_skipWs {json posVar} {
    upvar 1 $posVar pos
    set n [string length $json]
    while {$pos < $n && [string is space [string index $json $pos]]} {
        incr pos
    }
}

proc ::tclutils::tujson::_peek {json pos} {
    if {$pos >= [string length $json]} { return "" }
    return [string index $json $pos]
}

proc ::tclutils::tujson::_expect {json posVar char} {
    upvar 1 $posVar pos
    if {[_peek $json $pos] ne $char} {
        _fail $pos "expected '$char'"
    }
    incr pos
}

proc ::tclutils::tujson::_parseValue {json posVar} {
    upvar 1 $posVar pos
    _skipWs $json pos
    set ch [_peek $json $pos]
    switch -- $ch {
        "\{" { return [_parseObject $json pos] }
        "[" { return [_parseArray $json pos] }
        "\"" { return [_parseString $json pos] }
        "t" { return [_parseLiteral $json pos true 1] }
        "f" { return [_parseLiteral $json pos false 0] }
        "n" { return [_parseLiteral $json pos null ""] }
        "" { _fail $pos "unexpected end of input" }
        default {
            if {$ch eq "-" || [string is digit -strict $ch]} {
                return [_parseNumber $json pos]
            }
            _fail $pos "unexpected character '$ch'"
        }
    }
}

proc ::tclutils::tujson::_parseLiteral {json posVar literal value} {
    upvar 1 $posVar pos
    set n [string length $literal]
    if {[string range $json $pos [expr {$pos + $n - 1}]] ne $literal} {
        _fail $pos "expected '$literal'"
    }
    incr pos $n
    return $value
}

proc ::tclutils::tujson::_parseObject {json posVar} {
    upvar 1 $posVar pos
    set result [dict create]
    _expect $json pos "\{"
    _skipWs $json pos
    if {[_peek $json $pos] eq "\}"} {
        incr pos
        return $result
    }
    while 1 {
        _skipWs $json pos
        if {[_peek $json $pos] ne "\""} {
            _fail $pos "expected object key string"
        }
        set key [_parseString $json pos]
        _skipWs $json pos
        _expect $json pos ":"
        set value [_parseValue $json pos]
        dict set result $key $value
        _skipWs $json pos
        set ch [_peek $json $pos]
        if {$ch eq "\}"} {
            incr pos
            return $result
        } elseif {$ch eq ","} {
            incr pos
            continue
        } else {
            _fail $pos "expected ',' or '\}'"
        }
    }
}

proc ::tclutils::tujson::_parseArray {json posVar} {
    upvar 1 $posVar pos
    set result {}
    _expect $json pos "\["
    _skipWs $json pos
    if {[_peek $json $pos] eq "]"} {
        incr pos
        return $result
    }
    while 1 {
        lappend result [_parseValue $json pos]
        _skipWs $json pos
        set ch [_peek $json $pos]
        if {$ch eq "]"} {
            incr pos
            return $result
        } elseif {$ch eq ","} {
            incr pos
            continue
        } else {
            _fail $pos "expected ',' or ']'"
        }
    }
}

proc ::tclutils::tujson::_parseString {json posVar} {
    upvar 1 $posVar pos
    _expect $json pos "\""
    set out ""
    set n [string length $json]
    while {$pos < $n} {
        set ch [string index $json $pos]
        incr pos
        if {$ch eq "\""} {
            return $out
        }
        if {$ch eq "\\"} {
            if {$pos >= $n} { _fail $pos "unterminated escape" }
            set esc [string index $json $pos]
            incr pos
            switch -- $esc {
                "\"" { append out "\"" }
                "\\" { append out "\\" }
                "/"  { append out "/" }
                "b"  { append out "\b" }
                "f"  { append out "\f" }
                "n"  { append out "\n" }
                "r"  { append out "\r" }
                "t"  { append out "\t" }
                "u"  { append out [_parseUnicodeEscape $json pos] }
                default { _fail [expr {$pos - 1}] "invalid escape '$esc'" }
            }
            continue
        }
        scan $ch %c code
        if {$code < 0x20} {
            _fail [expr {$pos - 1}] "control character in string"
        }
        append out $ch
    }
    _fail $pos "unterminated string"
}

proc ::tclutils::tujson::_parseHex4 {json posVar} {
    upvar 1 $posVar pos
    if {$pos + 4 > [string length $json]} {
        _fail $pos "incomplete unicode escape"
    }
    set hex [string range $json $pos [expr {$pos + 3}]]
    if {![regexp {^[0-9A-Fa-f]{4}$} $hex]} {
        _fail $pos "invalid unicode escape"
    }
    incr pos 4
    scan $hex %x value
    return $value
}

proc ::tclutils::tujson::_codepointToChar {cp} {
    if {$cp < 0 || $cp > 0x10ffff} {
        return -code error -errorcode {TCLUTILS TUJSON UNICODE} \
            "unicode codepoint out of range: $cp"
    }
    return [::format %c $cp]
}

proc ::tclutils::tujson::_parseUnicodeEscape {json posVar} {
    upvar 1 $posVar pos
    set hi [_parseHex4 $json pos]
    if {$hi >= 0xD800 && $hi <= 0xDBFF} {
        # Surrogate pair.
        if {[string range $json $pos [expr {$pos + 1}]] ne "\\u"} {
            _fail $pos "missing low surrogate"
        }
        incr pos 2
        set lo [_parseHex4 $json pos]
        if {$lo < 0xDC00 || $lo > 0xDFFF} {
            _fail [expr {$pos - 4}] "invalid low surrogate"
        }
        set cp [expr {0x10000 + (($hi - 0xD800) << 10) + ($lo - 0xDC00)}]
        return [_codepointToChar $cp]
    }
    if {$hi >= 0xDC00 && $hi <= 0xDFFF} {
        _fail [expr {$pos - 4}] "unexpected low surrogate"
    }
    return [_codepointToChar $hi]
}

proc ::tclutils::tujson::_parseNumber {json posVar} {
    upvar 1 $posVar pos
    set start $pos
    set n [string length $json]

    if {[_peek $json $pos] eq "-"} { incr pos }
    if {$pos >= $n} { _fail $pos "incomplete number" }

    set ch [_peek $json $pos]
    if {$ch eq "0"} {
        incr pos
        if {$pos < $n && [string is digit -strict [_peek $json $pos]]} {
            _fail $pos "leading zero in number"
        }
    } elseif {[string is digit -strict $ch] && $ch ne "0"} {
        while {$pos < $n && [string is digit -strict [_peek $json $pos]]} { incr pos }
    } else {
        _fail $pos "invalid number"
    }

    if {[_peek $json $pos] eq "."} {
        incr pos
        if {$pos >= $n || ![string is digit -strict [_peek $json $pos]]} {
            _fail $pos "expected digit after decimal point"
        }
        while {$pos < $n && [string is digit -strict [_peek $json $pos]]} { incr pos }
    }

    set ch [_peek $json $pos]
    if {$ch eq "e" || $ch eq "E"} {
        incr pos
        set ch [_peek $json $pos]
        if {$ch eq "+" || $ch eq "-"} { incr pos }
        if {$pos >= $n || ![string is digit -strict [_peek $json $pos]]} {
            _fail $pos "expected digit in exponent"
        }
        while {$pos < $n && [string is digit -strict [_peek $json $pos]]} { incr pos }
    }

    return [string range $json $start [expr {$pos - 1}]]
}

proc ::tclutils::tujson::filePretty {infile outfile args} {
    set data [::tclutils::common::readFile $infile]
    set result [pretty $data {*}$args]
    ::tclutils::common::writeFile $outfile $result
    return $outfile
}

proc ::tclutils::tujson::fileMinify {infile outfile} {
    set data [::tclutils::common::readFile $infile]
    set result [minify $data]
    ::tclutils::common::writeFile $outfile $result
    return $outfile
}

# ---- JSON encoding -------------------------------------------------------
#
# toJson is the inverse of parseTyped. A "typed value" is the tagged
# representation that parseTyped produces:
#
#   string   {string  <text>}
#   number   {number  <numeric-text>}
#   boolean  {boolean true|false}
#   null     {null    {}}
#   object   {object  {key {typed} key {typed} ...}}
#   array    {array   {{typed} {typed} ...}}
#
# So `toJson [parseTyped $json]` round-trips $json. To build values by hand
# use the constructors str/num/bool/null/obj/arr, e.g.
#
#   toJson [obj [list name [str Alice] age [num 30] \
#                     tags [arr [list [str x] [str y]]]]] -indent 2
#
# With -indent N (N > 0) the output is pretty-printed with N spaces per level;
# otherwise it is compact.

proc ::tclutils::tujson::toJson {typed args} {
    set indent 0
    foreach {k v} $args {
        switch -- $k {
            -indent { set indent $v }
            default {
                return -code error -errorcode {TCLUTILS TUJSON OPTION} \
                    "unknown option \"$k\""
            }
        }
    }
    if {![string is integer -strict $indent] || $indent < 0} {
        return -code error -errorcode {TCLUTILS TUJSON OPTION} \
            "-indent must be a non-negative integer"
    }
    return [_emit $typed $indent 0]
}

proc ::tclutils::tujson::_emit {typed indent level} {
    set type [lindex $typed 0]
    set val  [lindex $typed 1]
    switch -- $type {
        string  { return [quote $val] }
        number  {
            if {![string is double -strict $val]} {
                return -code error -errorcode {TCLUTILS TUJSON NUMBER} \
                    "not a number: \"$val\""
            }
            return $val
        }
        boolean { return [expr {[string is true -strict $val] ? "true" : "false"}] }
        null    { return "null" }
        object  { return [_emitObject $val $indent $level] }
        array   { return [_emitArray  $val $indent $level] }
        default {
            return -code error -errorcode {TCLUTILS TUJSON TYPE} \
                "unknown JSON type \"$type\""
        }
    }
}

proc ::tclutils::tujson::_emitObject {pairs indent level} {
    if {[llength $pairs] % 2 != 0} {
        return -code error -errorcode {TCLUTILS TUJSON OBJECT} \
            "object needs an even number of key/value elements"
    }
    if {[llength $pairs] == 0} { return "\{\}" }
    set items {}
    set sub [expr {$level + 1}]
    if {$indent > 0} {
        set pad  [string repeat " " [expr {$indent * $sub}]]
        set pad2 [string repeat " " [expr {$indent * $level}]]
        foreach {k v} $pairs {
            lappend items "$pad[quote $k]: [_emit $v $indent $sub]"
        }
        return "\{\n[join $items ",\n"]\n$pad2\}"
    }
    foreach {k v} $pairs {
        lappend items "[quote $k]:[_emit $v $indent $sub]"
    }
    return "\{[join $items ,]\}"
}

proc ::tclutils::tujson::_emitArray {elems indent level} {
    if {[llength $elems] == 0} { return "\[\]" }
    set items {}
    set sub [expr {$level + 1}]
    if {$indent > 0} {
        set pad  [string repeat " " [expr {$indent * $sub}]]
        set pad2 [string repeat " " [expr {$indent * $level}]]
        foreach e $elems { lappend items "$pad[_emit $e $indent $sub]" }
        return "\[\n[join $items ",\n"]\n$pad2\]"
    }
    foreach e $elems { lappend items [_emit $e $indent $sub] }
    return "\[[join $items ,]\]"
}

# Typed-value constructors for building JSON by hand.
proc ::tclutils::tujson::str  {s} { return [list string $s] }
proc ::tclutils::tujson::num  {n} {
    if {![string is double -strict $n]} {
        return -code error -errorcode {TCLUTILS TUJSON NUMBER} "not a number: \"$n\""
    }
    return [list number $n]
}
proc ::tclutils::tujson::bool {b} {
    return [list boolean [expr {[string is true -strict $b] ? "true" : "false"}]]
}
proc ::tclutils::tujson::null {} { return [list null {}] }
proc ::tclutils::tujson::obj  {pairs} { return [list object $pairs] }
proc ::tclutils::tujson::arr  {elems} { return [list array $elems] }

package provide tclutils::tujson 0.1
