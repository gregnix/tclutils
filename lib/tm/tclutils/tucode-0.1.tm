# tclutils::tucode -- character code tables (ASCII, Latin-1/ANSI, signs)
# Description: character code tables (ASCII, Latin-1/ANSI, signs)
# Category: Encoding · binary/checksums
# Tcl 8.6+

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tucode {
    namespace export table ascii latin1 ansi signs lookup lookupChar render groups
    variable version 0.1
}

array set ::tclutils::tucode::controlNames {
    0 NUL  1 SOH  2 STX  3 ETX  4 EOT  5 ENQ  6 ACK  7 BEL
    8 BS   9 HT  10 LF  11 VT  12 FF  13 CR  14 SO  15 SI
    16 DLE 17 DC1 18 DC2 19 DC3 20 DC4 21 NAK 22 SYN 23 ETB
    24 CAN 25 EM  26 SUB 27 ESC 28 FS  29 GS  30 RS  31 US
    127 DEL
}

array set ::tclutils::tucode::latin1Names {
    128 PAD 129 HOP 130 BPH 131 NBH 132 IND 133 NEL 134 SSA 135 ESA
    136 HTS 137 HTJ 138 VTS 139 PLD 140 PLU 141 RI  142 SS2 143 SS3
    144 DCS 145 PU1 146 PU2 147 STS 148 CCH 149 MW  150 SPA 151 EPA
    152 SOS 153 SGCI 154 SCI 155 CSI 156 ST  157 OSC 158 PM  159 APC
    160 nbsp 161 iexcl 162 cent 163 pound 164 curren 165 yen 166 brkbar
    167 sect 168 uml 169 copy 170 ordf 171 laquo 172 not 173 shy 174 reg
    175 macr 176 deg 177 plusmn 178 sup2 179 sup3 180 acute 181 micro
    182 para 183 middot 184 cedil 185 sup1 186 ordm 187 raquo 188 frac14
    189 frac12 190 frac34 191 iquest 192 Agrave 193 Aacute 194 Acirc
    195 Atilde 196 Auml 197 Aring 198 AE 199 Ccedil 200 Egrave 201 Eacute
    202 Ecirc 203 Euml 204 Igrave 205 Iacute 206 Icirc 207 Iuml 208 ETH
    209 Ntilde 210 Ograve 211 Oacute 212 Ocirc 213 Otilde 214 Ouml
    215 times 216 Oslash 217 Ugrave 218 Uacute 219 Ucirc 220 Uuml
    221 Yacute 222 THORN 223 ssharp 224 agrave 225 aacute 226 acirc
    227 atilde 228 auml 229 aring 230 ae 231 ccedil 232 egrave 233 eacute
    234 ecirc 235 euml 236 igrave 237 iacute 238 icirc 239 iuml 240 eth
    241 ntilde 242 ograve 243 oacute 244 ocirc 245 otilde 246 ouml
    247 divide 248 oslash 249 ugrave 250 uacute 251 ucirc 252 uuml
    253 yacute 254 thorn 255 yuml
}

set ::tclutils::tucode::signGroups {
    controls   {title "C0 controls (0-31)" codes {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31}}
    whitespace {title "Whitespace" codes {9 10 13 32 160}}
    quotes     {title "Quotes and apostrophes" codes {34 39 96 180}}
    dashes     {title "Dashes and hyphen" codes {45 173}}
    german     {title "German letters (Latin-1)" codes {196 198 214 220 223 228 230 246 252}}
    currency   {title "Currency symbols" codes {36 162 163 164 165}}
    math       {title "Common math symbols (Latin-1)" codes {43 45 60 61 62 177 215 247}}
    latin1hi   {title "Latin-1 upper half sample" codes {128 169 174 176 181 191 215 247}}
    arrows     {title "Arrows (Unicode)" codes {8592 8593 8594 8595 8596 8597 8598 8599 8600 8601 8644 8656 8658 8660 8617 8618 8629}}
    boxdraw    {title "Box drawing (Unicode, light)" codes {9472 9474 9484 9488 9492 9496 9500 9508 9516 9524 9532}}
    boxdraw2   {title "Box drawing (Unicode, double)" codes {9552 9553 9556 9559 9562 9565 9568 9571 9574 9577 9580}}
}

array set ::tclutils::tucode::unicodeNames {
    8592 left 8593 up 8594 right 8595 down 8596 leftright 8597 updown
    8598 nw 8599 ne 8600 sw 8601 se 8644 leftoverright 8656 dleft 8658 dright
    8660 dleftright 8617 returnleft 8618 returnright 8629 downfrombar
    9472 hline 9474 vline 9484 downthenright 9488 downthenleft 9492 upthenright
    9496 upthenleft 9500 vthenright 9508 vthenleft 9516 hthendown 9524 hthenup 9532 cross
    9552 dhline 9553 dvline 9556 ddownthenright 9559 ddownthenleft 9562 dupthenright
    9565 dupthenleft 9568 dvthenright 9571 dvthenleft 9574 dhthendown 9577 dhthenup 9580 dcross
}

proc ::tclutils::tucode::_options {args} {
    set defaults [dict create -columns 4 -showName 1 -compact 0]
    return [::tclutils::common::parseOptions $defaults {*}$args]
}

proc ::tclutils::tucode::_byteToChar {code} {
    if {$code < 0 || $code > 255} {
        return -code error -errorcode {TCLUTILS TUCODE RANGE} "byte code out of range: $code"
    }
    if {$code < 128} {
        return [encoding convertfrom ascii [binary format cu $code]]
    }
    return [encoding convertfrom iso8859-1 [binary format cu $code]]
}

proc ::tclutils::tucode::_glyph {code} {
    if {$code < 32 || $code == 127} {
        return ^[format %c [expr {($code + 64) % 128}]]
    }
    set ch [_byteToChar $code]
    if {$ch eq "\\"} { return \\ }
    if {[string is graph -strict $ch]} { return $ch }
    if {$code == 32} { return "SP" }
    if {$code >= 128} {
        if {[string is print -strict $ch]} { return $ch }
    }
    return "."
}

proc ::tclutils::tucode::_name {code} {
    variable controlNames
    variable latin1Names
    if {[info exists controlNames($code)]} { return $controlNames($code) }
    if {$code >= 128 && [info exists latin1Names($code)]} { return $latin1Names($code) }
    if {$code >= 32 && $code <= 126} {
        return [_byteToChar $code]
    }
    return "?"
}

proc ::tclutils::tucode::_unicodeName {code} {
    variable unicodeNames
    if {[info exists unicodeNames($code)]} { return $unicodeNames($code) }
    return [format U+%04X $code]
}

proc ::tclutils::tucode::_unicodeGlyph {code} {
    set ch [format %c $code]
    if {[string is graph -strict $ch]} { return $ch }
    return "."
}

proc ::tclutils::tucode::_entry {code showName} {
    set glyph [_glyph $code]
    set hex [format %02X $code]
    if {$showName} {
        set name [_name $code]
        return [format "%3d %s  %-3s  %s" $code $hex $glyph $name]
    }
    return [format "%3d %s  %s" $code $hex $glyph]
}

proc ::tclutils::tucode::_unicodeEntry {code showName} {
    set glyph [_unicodeGlyph $code]
    if {$showName} {
        set name [_unicodeName $code]
        return [format "U+%04X  %-2s  %s" $code $glyph $name]
    }
    return [format "U+%04X  %s" $code $glyph]
}

proc ::tclutils::tucode::_signEntry {code showName} {
    if {$code <= 255} {
        return [_entry $code $showName]
    }
    return [_unicodeEntry $code $showName]
}

proc ::tclutils::tucode::_compact {from to} {
    set lines [list [format "%4s %s" "" "0123456789ABCDEF"]]
    for {set base $from} {$base <= $to} {incr base 16} {
        set cells {}
        for {set i 0} {$i < 16} {incr i} {
            set code [expr {$base + $i}]
            if {$code > $to} {
                lappend cells "  "
            } else {
                set g [_glyph $code]
                if {[string length $g] > 2} { set g [string range $g 0 1] }
                lappend cells [format "%-2s" $g]
            }
        }
        lappend lines [format "%02X  %s" $base [join $cells " "]]
    }
    return [join $lines \n]
}

proc ::tclutils::tucode::_parseCode {value} {
    set v [string trim $value]
    if {[regexp -nocase {^0x([0-9a-f]+)$} $v -> hex]} {
        set code 0x$hex
    } elseif {[regexp -nocase {^u\\+?([0-9a-f]+)$} $v -> hex]} {
        set ch [format %c 0x$hex]
        if {[catch {binary scan [encoding convertto iso8859-1 $ch] cu code} err]} {
            return -code error -errorcode {TCLUTILS TUCODE LOOKUP} "not a Latin-1 code point: $value"
        }
    } elseif {[string is integer -strict $v]} {
        set code $v
    } else {
        if {[catch {binary scan [encoding convertto iso8859-1 $v] cu code} err]} {
            return -code error -errorcode {TCLUTILS TUCODE LOOKUP} "cannot map character: $value"
        }
    }
    if {$code < 0 || $code > 255} {
        return -code error -errorcode {TCLUTILS TUCODE RANGE} "code out of byte range: $value"
    }
    return [expr {int($code)}]
}

proc ::tclutils::tucode::lookup {value} {
    set code [_parseCode $value]
    return [dict create \
        code $code \
        hex [format %02X $code] \
        oct [format %03o $code] \
        glyph [_glyph $code] \
        name [_name $code] \
        char [_byteToChar $code]]
}

proc ::tclutils::tucode::lookupChar {char} {
    return [lookup $char]
}

proc ::tclutils::tucode::render {from to args} {
    if {![string is integer -strict $from] || ![string is integer -strict $to]} {
        return -code error -errorcode {TCLUTILS TUCODE RANGE} "from/to must be integers"
    }
    if {$from > $to} { return -code error -errorcode {TCLUTILS TUCODE RANGE} "from > to" }
    if {$from < 0 || $to > 255} {
        return -code error -errorcode {TCLUTILS TUCODE RANGE} "range must be within 0..255"
    }

    set opts [_options {*}$args]
    set columns [::tclutils::common::ensurePositiveInteger [dict get $opts -columns] -columns]
    set showName [::tclutils::common::ensureBoolean [dict get $opts -showName] -showName]
    set compact [::tclutils::common::ensureBoolean [dict get $opts -compact] -compact]

    if {$compact} {
        return [_compact $from $to]
    }

    set count [expr {$to - $from + 1}]
    set rows [expr {($count + $columns - 1) / $columns}]
    set header [format "%3s %2s  %-3s  %s" Dec Hex Chr Name]
    set lines [list $header [string repeat - 40]]

    for {set r 0} {$r < $rows} {incr r} {
        set parts {}
        for {set c 0} {$c < $columns} {incr c} {
            set idx [expr {$r + $c * $rows}]
            set code [expr {$from + $idx}]
            if {$code > $to} {
                lappend parts [string repeat " " 16]
            } else {
                lappend parts [_entry $code $showName]
            }
        }
        lappend lines [join $parts " | "]
    }
    return [join $lines \n]
}

proc ::tclutils::tucode::table {from to args} {
    render $from $to {*}$args
}

proc ::tclutils::tucode::ascii {args} {
    render 0 127 {*}$args
}

proc ::tclutils::tucode::latin1 {args} {
    render 128 255 {*}$args
}

proc ::tclutils::tucode::ansi {args} {
    latin1 {*}$args
}

proc ::tclutils::tucode::groups {} {
    variable signGroups
    return [lsort [dict keys $signGroups]]
}

proc ::tclutils::tucode::signs {args} {
    set optArgs {}
    set groups {}
    foreach item $args {
        if {[string match -* $item]} {
            lappend optArgs $item
        } else {
            lappend groups $item
        }
    }
    set opts [_options {*}$optArgs]
    set showName [::tclutils::common::ensureBoolean [dict get $opts -showName] -showName]

    variable signGroups
    if {[llength $groups] == 0} {
        set groups [lsort [dict keys $signGroups]]
    }

    set out {}
    foreach g $groups {
        if {![dict exists $signGroups $g]} {
            return -code error -errorcode {TCLUTILS TUCODE GROUP} "unknown sign group: $g"
        }
        set sg [dict get $signGroups $g]
        lappend out [dict get $sg title]
        lappend out [string repeat - 40]
        foreach code [dict get $sg codes] {
            lappend out [_signEntry $code $showName]
        }
        lappend out ""
    }
    return [string trimright [join $out \n]]
}

package provide tclutils::tucode 0.1
