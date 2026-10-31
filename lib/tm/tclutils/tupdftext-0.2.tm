# tclutils::tupdftext -- text of a PDF, page by page, in pure Tcl
# Description: extract the text of a PDF per page (pure Tcl, no poppler)
# Category: Data · structures & formats
# Tcl 8.6+
#
# Reads a PDF and returns the text of every page. Meant for full-text search
# (book-search, mdserver), not for a faithful layout: words, spaces and line
# breaks come out, columns and tables only as far as the content order gives
# them.
#
#   package require tclutils::tupdftext
#   set texts [::tclutils::tupdftext::pages doc.pdf]   ;# one string per page
#   set all   [::tclutils::tupdftext::text  doc.pdf]
#   set facts [::tclutils::tupdftext::summary doc.pdf] ;# pages, fonts, ...
#
# What it reads:
#   - objects found by scanning for "N G obj" (the cross-reference table is not
#     needed, a damaged one does no harm; a later definition wins, as with an
#     incremental update), plus objects packed in object streams (/ObjStm)
#   - stream filters FlateDecode (with PNG/TIFF predictor), ASCIIHexDecode,
#     ASCII85Decode, LZWDecode; filter chains
#   - the page tree with inherited /Resources; a damaged tree falls back to all
#     /Type /Page objects in file order
#   - text operators Tj TJ ' " with Tf Tc Tw Tz TL Ts Td TD Tm T* and the
#     graphics state q Q cm; Form XObjects (Do) recursively
#   - fonts: Type0 (two-byte codes, Identity-H/V or an embedded CMap), Type1,
#     TrueType, Type3; Unicode from /ToUnicode, else from /Encoding
#     (WinAnsi, MacRoman, Standard, PDFDoc, /Differences with glyph names)
#   - spaces and line breaks from the positions (glyph widths from /Widths,
#     /W and /DW), not only from space characters
#
# What it does not do (errorcode {TCLUTILS TUPDFTEXT <kind>}):
#   ENCRYPTED  the file has an /Encrypt entry (no decryption)
#   NOTEXT     no page has any text: a scan without OCR, or only images;
#              option -notext empty returns empty strings instead
#   FORMAT     not a PDF, or no pages found
#   FILE       the file cannot be read
# A font with two-byte codes and no /ToUnicode gives U+FFFD per glyph; summary
# counts them under "unmapped". (The command is "summary", not "info": a proc
# named info in this namespace would shadow Tcl's info for the module.)

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tupdftext {
    namespace export pages text summary
    variable version 0.2
    variable maxFormDepth 8
}

proc ::tclutils::tupdftext::_err {kind msg} {
    return -code error -errorcode [list TCLUTILS TUPDFTEXT $kind] $msg
}

# ==================================================================
# Lexer and object parser
# ==================================================================
# Values are tagged lists:
#   {n 12.5} number   {s bytes} string   {N name}   {a {v ...}} array
#   {d {key v ...}} dictionary (keys without slash)   {r num gen} reference
#   {b 1} boolean     {z} null   {op name} operator (content streams only)

namespace eval ::tclutils::tupdftext {
    # whitespace and comments
    variable reWs {\A(?:[\0\t\n\f\r ]+|%[^\r\n]*)+}
    variable reName {\A/([^\0\t\n\f\r ()<>\[\]{}/%]*)}
    variable reNum {\A[+-]?(?:\d+\.?\d*|\.\d+)}
    variable reRef {\A(\d+)[\0\t\n\f\r ]+(\d+)[\0\t\n\f\r ]+R(?![^\0\t\n\f\r ()<>\[\]{}/%])}
    variable reWord {\A[^\0\t\n\f\r ()<>\[\]{}/%]+}
}

proc ::tclutils::tupdftext::_skipWs {data i} {
    variable reWs
    if {[regexp -indices -start $i $reWs $data m]} {
        return [expr {[lindex $m 1] + 1}]
    }
    return $i
}

# Parse one value at index i. Returns {value nextIndex}; value "" at the end.
proc ::tclutils::tupdftext::_parse {data i} {
    variable reName; variable reNum; variable reRef; variable reWord
    set i [_skipWs $data $i]
    set c [string index $data $i]
    switch -- $c {
        "" { return [list "" $i] }
        "<" {
            if {[string index $data [expr {$i + 1}]] eq "<"} {
                set i [expr {$i + 2}]
                set d {}
                while 1 {
                    set i [_skipWs $data $i]
                    if {[string range $data $i [expr {$i + 1}]] eq ">>"} {
                        return [list [list d $d] [expr {$i + 2}]]
                    }
                    if {$i >= [string length $data]} { return [list [list d $d] $i] }
                    lassign [_parse $data $i] k i
                    if {[lindex $k 0] ne "N"} {
                        # malformed key: skip it
                        if {$k eq ""} { return [list [list d $d] $i] }
                        continue
                    }
                    lassign [_parse $data $i] v i
                    lappend d [lindex $k 1] $v
                }
            }
            set e [string first > $data $i]
            if {$e < 0} { set e [string length $data] }
            set hex [regsub -all {[^0-9A-Fa-f]} [string range $data [expr {$i + 1}] [expr {$e - 1}]] ""]
            if {[string length $hex] % 2} { append hex 0 }
            return [list [list s [binary format H* $hex]] [expr {$e + 1}]]
        }
        "(" { return [_literal $data $i] }
        "\[" {
            incr i
            set a {}
            while 1 {
                set i [_skipWs $data $i]
                set c [string index $data $i]
                if {$c eq "\]"} { return [list [list a $a] [expr {$i + 1}]] }
                if {$c eq ""} { return [list [list a $a] $i] }
                lassign [_parse $data $i] v i
                if {$v ne ""} { lappend a $v }
            }
        }
        "/" {
            regexp -indices -start $i $reName $data m g
            set name [string range $data {*}$g]
            if {[string first # $name] >= 0} { set name [_unhashName $name] }
            return [list [list N $name] [expr {[lindex $m 1] + 1}]]
        }
        ">" - "\]" - ")" - "\{" - "\}" {
            # stray delimiter: skip
            return [_parse $data [expr {$i + 1}]]
        }
    }
    if {[regexp -indices -start $i $reRef $data m g1 g2]} {
        return [list [list r [string range $data {*}$g1] [string range $data {*}$g2]] \
                    [expr {[lindex $m 1] + 1}]]
    }
    if {[regexp -indices -start $i $reNum $data m]} {
        return [list [list n [string range $data {*}$m]] [expr {[lindex $m 1] + 1}]]
    }
    if {[regexp -indices -start $i $reWord $data m]} {
        set w [string range $data {*}$m]
        set j [expr {[lindex $m 1] + 1}]
        switch -- $w {
            true  { return [list {b 1} $j] }
            false { return [list {b 0} $j] }
            null  { return [list {z} $j] }
        }
        return [list [list op $w] $j]
    }
    return [list "" [expr {$i + 1}]]
}

# /A#20B -> "A B"
proc ::tclutils::tupdftext::_unhashName {name} {
    set out ""
    set i 0
    while {[regexp -indices -start $i {#([0-9A-Fa-f]{2})} $name m g]} {
        append out [string range $name $i [expr {[lindex $m 0] - 1}]]
        append out [format %c [scan [string range $name {*}$g] %x]]
        set i [expr {[lindex $m 1] + 1}]
    }
    return "$out[string range $name $i end]"
}

# Literal string (...) with nesting and escapes, starting at "(".
proc ::tclutils::tupdftext::_literal {data i} {
    set out ""
    set depth 1
    set j [expr {$i + 1}]
    set n [string length $data]
    while {$j < $n} {
        if {![regexp -indices -start $j {[()\\]} $data m]} {
            append out [string range $data $j end]
            return [list [list s $out] $n]
        }
        set k [lindex $m 0]
        append out [string range $data $j [expr {$k - 1}]]
        set c [string index $data $k]
        if {$c eq "("} {
            incr depth; append out "("; set j [expr {$k + 1}]
        } elseif {$c eq ")"} {
            incr depth -1
            if {$depth == 0} { return [list [list s $out] [expr {$k + 1}]] }
            append out ")"; set j [expr {$k + 1}]
        } else {
            set e [string index $data [expr {$k + 1}]]
            set j [expr {$k + 2}]
            switch -- $e {
                n { append out \n }  r { append out \r }  t { append out \t }
                b { append out \b }  f { append out \f }
                ( - ) - \\ { append out $e }
                \r { if {[string index $data $j] eq "\n"} { incr j } }
                \n {}
                default {
                    if {[regexp -start [expr {$k + 1}] {\A[0-7]{1,3}} $data oct]} {
                        append out [format %c [expr {"0o$oct" & 0xff}]]
                        set j [expr {$k + 1 + [string length $oct]}]
                    } else {
                        append out $e
                    }
                }
            }
        }
    }
    return [list [list s $out] $n]
}

# ==================================================================
# Document: object table, streams
# ==================================================================
# A document is an array ::tclutils::tupdftext::D<n> with
#   data, off(<num>) offsets, stm(<num>) {objstm index}, obj(<num>) cache

proc ::tclutils::tupdftext::_open {file} {
    variable seq
    if {![info exists seq]} { set seq 0 }
    if {[catch {::tclutils::common::readBinaryFile $file} data]} {
        _err FILE "cannot read \"$file\": $data"
    }
    if {[string first %PDF- [string range $data 0 1023]] < 0} {
        _err FORMAT "not a PDF (no %PDF- header): $file"
    }
    set doc ::tclutils::tupdftext::D[incr seq]
    upvar #0 $doc D
    set D(data) $data
    set D(file) $file
    # "N G obj" at the start of a line; a later definition replaces an
    # earlier one (incremental update)
    foreach {m g1 g2} [regexp -all -indices -inline \
            {(?:\A|[\r\n])[ \t]*(\d+)[ \t\r\n]+(\d+)[ \t\r\n]+obj(?![^\0\t\n\f\r ()<>\[\]{}/%])} $data] {
        set num [string range $data {*}$g1]
        set D(off,$num) [expr {[lindex $m 1] + 1}]
        lappend D(starts) [lindex $m 1] $num
    }
    if {![info exists D(starts)]} {
        unset D
        _err FORMAT "no objects found: $file"
    }
    # object streams fill in the numbers not defined directly
    foreach num [_objectsWith $doc /ObjStm] {
        set v [_obj $doc $num]
        if {[lindex $v 0] ne "stream"} continue
        set dict [lindex $v 1]
        if {[_dget $doc $dict Type] ne {N ObjStm}} continue
        if {[catch {_streamData $doc $v} dec]} continue
        set n [lindex [_dget $doc $dict N] 1]
        set first [lindex [_dget $doc $dict First] 1]
        if {![string is integer -strict $n] || ![string is integer -strict $first]} continue
        set nums [regexp -all -inline {\d+} [string range $dec 0 [expr {$first - 1}]]]
        for {set k 0} {$k < $n} {incr k} {
            set onum [lindex $nums [expr {2 * $k}]]
            set ooff [lindex $nums [expr {2 * $k + 1}]]
            if {$onum eq "" || [info exists D(off,$onum)]} continue
            set D(stmdata,$num) $dec
            set D(stm,$onum) [list $num [expr {$first + $ooff}]]
        }
    }
    return $doc
}

proc ::tclutils::tupdftext::_close {doc} {
    catch {unset $doc}
}

# Object numbers whose definition contains the given text (e.g. /ObjStm):
# the object that starts last before each occurrence.
proc ::tclutils::tupdftext::_objectsWith {doc needle} {
    upvar #0 $doc D
    set starts $D(starts)
    set pos {}
    foreach {s num} $starts { lappend pos $s }
    set out {}
    set i 0
    while {[set p [string first $needle $D(data) $i]] >= 0} {
        set k [lsearch -integer -bisect $pos $p]
        if {$k >= 0} {
            set num [lindex $starts [expr {2 * $k + 1}]]
            if {$num ni $out} { lappend out $num }
        }
        set i [expr {$p + [string length $needle]}]
    }
    return $out
}

# Object by number: a value, or {stream dict dataStart dataEnd}.
proc ::tclutils::tupdftext::_obj {doc num} {
    upvar #0 $doc D
    if {[info exists D(obj,$num)]} { return $D(obj,$num) }
    set D(obj,$num) {z}   ;# guards against reference loops while parsing
    if {[info exists D(off,$num)]} {
        lassign [_parse $D(data) $D(off,$num)] v j
        if {[lindex $v 0] eq "d"} {
            set k [_skipWs $D(data) $j]
            if {[string range $D(data) $k [expr {$k + 5}]] eq "stream"} {
                set s [expr {$k + 6}]
                if {[string index $D(data) $s] eq "\r"} { incr s }
                if {[string index $D(data) $s] eq "\n"} { incr s }
                set e -1
                set len [_dget $doc [lindex $v 1] Length]
                if {[lindex $len 0] eq "n" && [string is integer -strict [lindex $len 1]]} {
                    set e [expr {$s + [lindex $len 1]}]
                    set after [_skipWs $D(data) $e]
                    if {[string range $D(data) $after [expr {$after + 8}]] ne "endstream"} {
                        set e -1
                    }
                }
                if {$e < 0} {
                    set e [string first endstream $D(data) $s]
                    if {$e < 0} { set e [string length $D(data)] }
                    # drop the end-of-line before "endstream"
                    if {[string index $D(data) [expr {$e - 1}]] eq "\n"} { incr e -1 }
                    if {[string index $D(data) [expr {$e - 1}]] eq "\r"} { incr e -1 }
                }
                set v [list stream [lindex $v 1] $s $e]
            }
        }
        set D(obj,$num) $v
    } elseif {[info exists D(stm,$num)]} {
        lassign $D(stm,$num) sn off
        lassign [_parse $D(stmdata,$sn) $off] v
        set D(obj,$num) $v
    }
    return $D(obj,$num)
}

# Resolve a reference (any depth); other values come back as they are.
proc ::tclutils::tupdftext::_res {doc v} {
    set n 0
    while {[lindex $v 0] eq "r" && [incr n] < 32} {
        set v [_obj $doc [lindex $v 1]]
    }
    return $v
}

# Value of a dictionary key, resolved. dict is the inner list {k v ...}.
proc ::tclutils::tupdftext::_dget {doc dict key} {
    foreach {k v} $dict {
        if {$k eq $key} { return [_res $doc $v] }
    }
    return ""
}

# Dictionary of a value (dict or stream), as inner list.
proc ::tclutils::tupdftext::_dictOf {v} {
    switch -- [lindex $v 0] {
        d      { return [lindex $v 1] }
        stream { return [lindex $v 1] }
    }
    return {}
}

proc ::tclutils::tupdftext::_num {v {def 0}} {
    if {[lindex $v 0] eq "n"} { return [lindex $v 1] }
    return $def
}

# ==================================================================
# Stream filters
# ==================================================================

proc ::tclutils::tupdftext::_streamData {doc v} {
    upvar #0 $doc D
    lassign $v - dict s e
    if {[info exists D(stmsrc,$s)]} {
        set raw $D(stmsrc,$s)
    } else {
        set raw [string range $D(data) $s [expr {$e - 1}]]
    }
    set f [_dget $doc $dict Filter]
    set p [_dget $doc $dict DecodeParms]
    if {$f eq ""} { return $raw }
    if {[lindex $f 0] eq "N"} {
        set filters [list [lindex $f 1]]
        set parms [list $p]
    } else {
        set filters {}
        foreach x [lindex $f 1] { lappend filters [lindex [_res $doc $x] 1] }
        set parms {}
        if {[lindex $p 0] eq "a"} {
            foreach x [lindex $p 1] { lappend parms [_res $doc $x] }
        }
    }
    foreach flt $filters prm $parms {
        set raw [_filter $doc $flt $raw $prm]
    }
    return $raw
}

proc ::tclutils::tupdftext::_filter {doc name raw parm} {
    switch -- $name {
        FlateDecode - Fl {
            if {[catch {zlib decompress $raw} out]} {
                if {[catch {zlib inflate $raw} out]} {
                    # damaged tail: take what a streaming inflate gives
                    set out [_inflatePartial $raw]
                    if {$out eq ""} { _err FILTER "FlateDecode failed" }
                }
            }
            return [_predictor $doc $out $parm]
        }
        ASCIIHexDecode - AHx {
            set hex [regsub -all {[^0-9A-Fa-f]} [lindex [split $raw >] 0] ""]
            if {[string length $hex] % 2} { append hex 0 }
            return [binary format H* $hex]
        }
        ASCII85Decode - A85 { return [_a85 $raw] }
        LZWDecode - LZW { return [_predictor $doc [_lzw $raw $parm] $parm] }
        default { _err FILTER "unsupported filter $name" }
    }
}

proc ::tclutils::tupdftext::_inflatePartial {raw} {
    set out ""
    catch {
        set z [zlib stream decompress]
        $z put $raw
        $z flush
        set out [$z get]
        $z close
    }
    return $out
}

proc ::tclutils::tupdftext::_predictor {doc data parm} {
    if {[lindex $parm 0] ne "d"} { return $data }
    set dict [lindex $parm 1]
    set pred [_num [_dget $doc $dict Predictor] 1]
    if {$pred < 10} { return $data }
    set colors [_num [_dget $doc $dict Colors] 1]
    set bpc [_num [_dget $doc $dict BitsPerComponent] 8]
    set cols [_num [_dget $doc $dict Columns] 1]
    set bpp [expr {max(1, ($colors * $bpc + 7) / 8)}]
    set rowLen [expr {($colors * $bpc * $cols + 7) / 8}]
    binary scan $data cu* bytes
    set out {}
    set prev [lrepeat $rowLen 0]
    set n [llength $bytes]
    for {set i 0} {$i + $rowLen < $n + 1 && $i < $n} {incr i [expr {$rowLen + 1}]} {
        set type [lindex $bytes $i]
        set row [lrange $bytes [expr {$i + 1}] [expr {$i + $rowLen}]]
        set cur {}
        for {set k 0} {$k < [llength $row]} {incr k} {
            set x [lindex $row $k]
            set a [expr {$k >= $bpp ? [lindex $cur [expr {$k - $bpp}]] : 0}]
            set b [lindex $prev $k]
            set c [expr {$k >= $bpp ? [lindex $prev [expr {$k - $bpp}]] : 0}]
            switch -- $type {
                1 { set x [expr {($x + $a) & 255}] }
                2 { set x [expr {($x + $b) & 255}] }
                3 { set x [expr {($x + ($a + $b) / 2) & 255}] }
                4 {
                    set p [expr {$a + $b - $c}]
                    set pa [expr {abs($p - $a)}]; set pb [expr {abs($p - $b)}]
                    set pc [expr {abs($p - $c)}]
                    if {$pa <= $pb && $pa <= $pc} { set pr $a } \
                    elseif {$pb <= $pc} { set pr $b } else { set pr $c }
                    set x [expr {($x + $pr) & 255}]
                }
            }
            lappend cur $x
        }
        lappend out {*}$cur
        set prev $cur
    }
    return [binary format cu* $out]
}

proc ::tclutils::tupdftext::_a85 {raw} {
    set raw [regsub -all {[\s]} $raw ""]
    if {[string match <~* $raw]} { set raw [string range $raw 2 end] }
    set e [string first ~> $raw]
    if {$e >= 0} { set raw [string range $raw 0 [expr {$e - 1}]] }
    set out ""
    set grp {}
    foreach ch [split $raw ""] {
        if {$ch eq "z" && [llength $grp] == 0} {
            append out "\0\0\0\0"; continue
        }
        scan $ch %c c
        lappend grp [expr {$c - 33}]
        if {[llength $grp] == 5} {
            set v 0
            foreach d $grp { set v [expr {$v * 85 + $d}] }
            append out [binary format Iu [expr {$v & 0xffffffff}]]
            set grp {}
        }
    }
    if {[set m [llength $grp]] > 1} {
        set v 0
        foreach d [concat $grp [lrepeat [expr {5 - $m}] 84]] { set v [expr {$v * 85 + $d}] }
        append out [string range [binary format Iu [expr {$v & 0xffffffff}]] 0 [expr {$m - 2}]]
    }
    return $out
}

proc ::tclutils::tupdftext::_lzw {raw parm} {
    binary scan $raw cu* bytes
    set early 1
    if {[lindex $parm 0] eq "d"} {
        foreach {k v} [lindex $parm 1] {
            if {$k eq "EarlyChange"} { set early [lindex $v 1] }
        }
    }
    set out ""
    set bits 0; set nbits 0; set width 9
    set table {}
    for {set i 0} {$i < 256} {incr i} { lappend table [format %c $i] }
    lappend table "" ""
    set prev ""
    foreach b $bytes {
        set bits [expr {($bits << 8) | $b}]
        incr nbits 8
        while {$nbits >= $width} {
            set code [expr {($bits >> ($nbits - $width)) & ((1 << $width) - 1)}]
            incr nbits -$width
            set bits [expr {$bits & ((1 << $nbits) - 1)}]
            if {$code == 256} {
                set table [lrange $table 0 257]; set width 9; set prev ""; continue
            }
            if {$code == 257} { return $out }
            if {$code < [llength $table]} {
                set entry [lindex $table $code]
            } elseif {$prev ne ""} {
                set entry "$prev[string index $prev 0]"
            } else {
                return $out
            }
            append out $entry
            if {$prev ne ""} { lappend table "$prev[string index $entry 0]" }
            set prev $entry
            set limit [expr {(1 << $width) - $early}]
            if {[llength $table] >= $limit && $width < 12} { incr width }
        }
    }
    return $out
}

# ==================================================================
# Encodings and glyph names
# ==================================================================

namespace eval ::tclutils::tupdftext {
    # glyph names in WinAnsi order, 0x20..0xFF ("-" = no glyph)
    variable winNames {
        space exclam quotedbl numbersign dollar percent ampersand quotesingle
        parenleft parenright asterisk plus comma hyphen period slash
        zero one two three four five six seven eight nine colon semicolon
        less equal greater question at A B C D E F G H I J K L M N O P Q R S T
        U V W X Y Z bracketleft backslash bracketright asciicircum underscore
        grave a b c d e f g h i j k l m n o p q r s t u v w x y z braceleft bar
        braceright asciitilde -
        Euro - quotesinglbase florin quotedblbase ellipsis dagger daggerdbl
        circumflex perthousand Scaron guilsinglleft OE - Zcaron -
        - quoteleft quoteright quotedblleft quotedblright bullet endash emdash
        tilde trademark scaron guilsinglright oe - zcaron Ydieresis
        nbspace exclamdown cent sterling currency yen brokenbar section dieresis
        copyright ordfeminine guillemotleft logicalnot sfthyphen registered
        macron degree plusminus twosuperior threesuperior acute mu paragraph
        periodcentered cedilla onesuperior ordmasculine guillemotright
        onequarter onehalf threequarters questiondown Agrave Aacute Acircumflex
        Atilde Adieresis Aring AE Ccedilla Egrave Eacute Ecircumflex Edieresis
        Igrave Iacute Icircumflex Idieresis Eth Ntilde Ograve Oacute Ocircumflex
        Otilde Odieresis multiply Oslash Ugrave Uacute Ucircumflex Udieresis
        Yacute Thorn germandbls agrave aacute acircumflex atilde adieresis aring
        ae ccedilla egrave eacute ecircumflex edieresis igrave iacute icircumflex
        idieresis eth ntilde ograve oacute ocircumflex otilde odieresis divide
        oslash ugrave uacute ucircumflex udieresis yacute thorn ydieresis
    }
    # names outside WinAnsi that turn up in /Differences
    variable extraNames {
        fi ﬁ fl ﬂ ff ﬀ ffi ﬃ ffl ﬄ dotlessi ı
        minus − fraction ⁄ space   Lslash Ł lslash ł
        Zcaron Ž zcaron ž caron ˇ breve ˘ dotaccent ˙
        ring ˚ ogonek ˛ hungarumlaut ˝ quotesingle '
        Delta ∆ Omega Ω pi π mu µ lozenge ◊
        notequal ≠ lessequal ≤ greaterequal ≥ infinity ∞
        summation ∑ product ∏ radical √ integral ∫
        partialdiff ∂ approxequal ≈ arrowright → arrowleft ←
        arrowup ↑ arrowdown ↓ apple 
    }
    variable glyphMap
    variable encTables
}

proc ::tclutils::tupdftext::_initTables {} {
    variable glyphMap; variable encTables; variable winNames; variable extraNames
    if {[info exists encTables(WinAnsiEncoding)]} return
    set opts {}
    if {[package vsatisfies [info tclversion] 9-]} { set opts {-profile replace} }
    foreach {enc tcl} {WinAnsiEncoding cp1252 MacRomanEncoding macRoman
                       PDFDocEncoding iso8859-1} {
        set t {}
        for {set i 0} {$i < 256} {incr i} {
            if {$i < 32} {
                if {$i in {9 10 13}} {
                    lappend t [format %c $i]
                } else {
                    lappend t ""
                }
                continue
            }
            if {[catch {encoding convertfrom {*}$opts $tcl [format %c $i]} ch]} {
                set ch ""
            }
            lappend t $ch
        }
        set encTables($enc) $t
    }
    # StandardEncoding: ASCII with curly quotes, upper half rarely used
    set t $encTables(PDFDocEncoding)
    lset t 39 ’
    lset t 96 ‘
    set encTables(StandardEncoding) $t
    # glyph names: WinAnsi order plus the extra ones
    set code 32
    foreach n $winNames {
        if {$n ne "-"} { set glyphMap($n) [lindex $encTables(WinAnsiEncoding) $code] }
        incr code
    }
    set glyphMap(nbspace)
    set glyphMap(sfthyphen) ­
    foreach {n ch} $extraNames { set glyphMap($n) $ch }
}

# Unicode for a glyph name (uniXXXX, uXXXX[XX], known names, "a12" -> "").
proc ::tclutils::tupdftext::_glyph {name} {
    variable glyphMap
    if {[info exists glyphMap($name)]} { return $glyphMap($name) }
    set base [lindex [split $name ._] 0]
    if {[regexp {^uni((?:[0-9A-F]{4})+)$} $base -> hex]} {
        return [_utf16 [binary format H* $hex]]
    }
    if {[regexp {^u([0-9A-F]{4,6})$} $base -> hex]} {
        return [_chr [scan $hex %x]]
    }
    if {[info exists glyphMap($base)]} { return $glyphMap($base) }
    if {[string length $base] == 1} { return $base }
    return ""
}

proc ::tclutils::tupdftext::_chr {cp} {
    if {$cp > 0xFFFF && ![package vsatisfies [info tclversion] 9-]} {
        # Tcl 8.6: outside the BMP as a surrogate pair
        set cp [expr {$cp - 0x10000}]
        return [format %c%c [expr {0xD800 + ($cp >> 10)}] [expr {0xDC00 + ($cp & 0x3FF)}]]
    }
    return [format %c $cp]
}

# UTF-16BE bytes to a string (surrogate pairs joined on Tcl 9).
proc ::tclutils::tupdftext::_utf16 {bytes} {
    binary scan $bytes Su* units
    set out ""
    set n [llength $units]
    for {set i 0} {$i < $n} {incr i} {
        set u [lindex $units $i]
        if {$u >= 0xD800 && $u < 0xDC00 && $i + 1 < $n} {
            set lo [lindex $units [expr {$i + 1}]]
            if {$lo >= 0xDC00 && $lo < 0xE000} {
                append out [_chr [expr {0x10000 + (($u - 0xD800) << 10) + ($lo - 0xDC00)}]]
                incr i
                continue
            }
        }
        if {$u >= 0xD800 && $u < 0xE000} {
            # a lone surrogate is no character (Tcl 9 cannot write it)
            append out \uFFFD
            continue
        }
        append out [format %c $u]
    }
    return $out
}

# ==================================================================
# Fonts
# ==================================================================
# Font info (dict): twoByte, spaces {{lo hi len} ...}, uni (dict code->text),
# enc (list of 256 texts, simple fonts), widths (dict code->w), dw default
# width, scale (glyph units to text space per 1 unit of size), mapped,
# name, subtype

proc ::tclutils::tupdftext::_font {doc ref} {
    upvar #0 $doc D
    if {[lindex $ref 0] eq "r"} {
        set key [lindex $ref 1]
    } else {
        set key $ref
    }
    if {[info exists D(font,$key)]} { return $D(font,$key) }
    _initTables
    variable encTables
    set fv [_res $doc $ref]
    set fd [_dictOf $fv]
    set subtype [lindex [_dget $doc $fd Subtype] 1]
    set base [lindex [_dget $doc $fd BaseFont] 1]
    set f [dict create name $base subtype $subtype twoByte 0 spaces {} \
        uni {} enc {} widths {} dw 500 scale 0.001 mapped 0]
    # ToUnicode
    set tu [_dget $doc $fd ToUnicode]
    if {[lindex $tu 0] eq "stream" && ![catch {_streamData $doc $tu} cm]} {
        lassign [_cmap $cm] uni spaces
        dict set f uni $uni
        dict set f spaces $spaces
        dict set f mapped 1
    }
    if {$subtype eq "Type0"} {
        dict set f twoByte 1
        set encv [_dget $doc $fd Encoding]
        if {[lindex $encv 0] eq "stream" && ![catch {_streamData $doc $encv} ecm]} {
            lassign [_cmap $ecm] - sp2
            if {[llength $sp2]} { dict set f spaces $sp2 }
        }
        if {[llength [dict get $f spaces]] == 0} {
            dict set f spaces {{0 65535 2}}
        }
        set desc [_res $doc [lindex [lindex [_dget $doc $fd DescendantFonts] 1] 0]]
        set dd [_dictOf $desc]
        dict set f dw [_num [_dget $doc $dd DW] 1000]
        set w [_dget $doc $dd W]
        if {[lindex $w 0] eq "a"} {
            set items [lmap x [lindex $w 1] { _res $doc $x }]
            set widths {}
            set i 0
            set n [llength $items]
            while {$i < $n} {
                set c1 [_num [lindex $items $i]]
                set nx [lindex $items [expr {$i + 1}]]
                if {[lindex $nx 0] eq "a"} {
                    set c $c1
                    foreach x [lindex $nx 1] { dict set widths $c [_num [_res $doc $x]]; incr c }
                    incr i 2
                } else {
                    set c2 [_num $nx]
                    set wv [_num [lindex $items [expr {$i + 2}]]]
                    if {$c2 - $c1 < 70000} {
                        for {set c $c1} {$c <= $c2} {incr c} { dict set widths $c $wv }
                    }
                    incr i 3
                }
            }
            dict set f widths $widths
        }
        return [set D(font,$key) $f]
    }
    # simple fonts: encoding
    set enc $encTables(StandardEncoding)
    if {$subtype eq "TrueType"} { set enc $encTables(WinAnsiEncoding) }
    set ev [_dget $doc $fd Encoding]
    if {[lindex $ev 0] eq "N" && [info exists encTables([lindex $ev 1])]} {
        set enc $encTables([lindex $ev 1])
    } elseif {[lindex $ev 0] eq "d"} {
        set be [_dget $doc [lindex $ev 1] BaseEncoding]
        if {[lindex $be 0] eq "N" && [info exists encTables([lindex $be 1])]} {
            set enc $encTables([lindex $be 1])
        }
        set diff [_dget $doc [lindex $ev 1] Differences]
        if {[lindex $diff 0] eq "a"} {
            set code 0
            foreach x [lindex $diff 1] {
                if {[lindex $x 0] eq "n"} {
                    set code [expr {int([lindex $x 1])}]
                } elseif {[lindex $x 0] eq "N"} {
                    if {$code >= 0 && $code < 256} { lset enc $code [_glyph [lindex $x 1]] }
                    incr code
                }
            }
        }
    }
    dict set f enc $enc
    # widths
    set first [_num [_dget $doc $fd FirstChar] 0]
    set wa [_dget $doc $fd Widths]
    set widths {}
    if {[lindex $wa 0] eq "a"} {
        set c [expr {int($first)}]
        foreach x [lindex $wa 1] { dict set widths $c [_num [_res $doc $x]]; incr c }
    }
    dict set f widths $widths
    set fdesc [_dictOf [_dget $doc $fd FontDescriptor]]
    set mw [_num [_dget $doc $fdesc MissingWidth] 0]
    dict set f dw [expr {$mw > 0 ? $mw : 500}]
    if {$subtype eq "Type3"} {
        set fm [_dget $doc $fd FontMatrix]
        if {[lindex $fm 0] eq "a"} {
            dict set f scale [_num [_res $doc [lindex [lindex $fm 1] 0]] 0.001]
        }
    }
    return [set D(font,$key) $f]
}

# ToUnicode / embedded CMap: {uniDict codespaces}
proc ::tclutils::tupdftext::_cmap {cm} {
    set uni {}
    set spaces {}
    set i 0
    set mode ""
    set stack {}
    while 1 {
        lassign [_parse $cm $i] v i
        if {$v eq ""} break
        if {[lindex $v 0] eq "op"} {
            set op [lindex $v 1]
            switch -- $op {
                begincodespacerange - beginbfchar - beginbfrange - begincidrange - begincidchar {
                    set mode $op; set stack {}
                }
                endcodespacerange {
                    foreach {lo hi} $stack {
                        set len [string length [lindex $lo 1]]
                        lappend spaces [list [_bytesNum [lindex $lo 1]] [_bytesNum [lindex $hi 1]] $len]
                    }
                    set mode ""
                }
                endbfchar {
                    foreach {src dst} $stack {
                        if {[lindex $dst 0] eq "s"} {
                            dict set uni [_bytesNum [lindex $src 1]] [_utf16 [lindex $dst 1]]
                        } elseif {[lindex $dst 0] eq "N"} {
                            dict set uni [_bytesNum [lindex $src 1]] [_glyph [lindex $dst 1]]
                        }
                    }
                    set mode ""
                }
                endbfrange {
                    foreach {lo hi dst} $stack {
                        set a [_bytesNum [lindex $lo 1]]
                        set b [_bytesNum [lindex $hi 1]]
                        if {$b - $a > 65535} continue
                        if {[lindex $dst 0] eq "a"} {
                            set c $a
                            foreach x [lindex $dst 1] {
                                if {$c > $b} break
                                dict set uni $c [_utf16 [lindex $x 1]]
                                incr c
                            }
                        } elseif {[lindex $dst 0] eq "s"} {
                            set bytes [lindex $dst 1]
                            set head [string range $bytes 0 end-2]
                            binary scan [string range $bytes end-1 end] Su last
                            for {set c $a} {$c <= $b} {incr c} {
                                dict set uni $c [_utf16 "$head[binary format S [expr {($last + $c - $a) & 0xFFFF}]]"]
                            }
                        }
                    }
                    set mode ""
                }
                default {}
            }
            continue
        }
        if {$mode ne ""} { lappend stack $v }
    }
    return [list $uni $spaces]
}

proc ::tclutils::tupdftext::_bytesNum {bytes} {
    set n 0
    binary scan $bytes cu* bs
    foreach b $bs { set n [expr {($n << 8) | $b}] }
    return $n
}

# Split a shown string into glyphs: list of {code text width}.
proc ::tclutils::tupdftext::_glyphs {font bytes} {
    binary scan $bytes cu* bs
    set out {}
    set uni [dict get $font uni]
    set widths [dict get $font widths]
    set dw [dict get $font dw]
    if {[dict get $font twoByte]} {
        set spaces [dict get $font spaces]
        set n [llength $bs]
        set i 0
        while {$i < $n} {
            set len 2
            set c1 [lindex $bs $i]
            foreach sp $spaces {
                lassign $sp lo hi l
                if {$l == 1 && $c1 >= $lo && $c1 <= $hi} { set len 1; break }
            }
            set code 0
            foreach b [lrange $bs $i [expr {$i + $len - 1}]] { set code [expr {($code << 8) | $b}] }
            incr i $len
            if {[dict exists $uni $code]} {
                set t [dict get $uni $code]
            } else {
                set t �
            }
            set w [expr {[dict exists $widths $code] ? [dict get $widths $code] : $dw}]
            lappend out [list $code $t $w]
        }
        return $out
    }
    set enc [dict get $font enc]
    foreach b $bs {
        if {[dict exists $uni $b]} {
            set t [dict get $uni $b]
        } else {
            set t [lindex $enc $b]
        }
        set w [expr {[dict exists $widths $b] ? [dict get $widths $b] : $dw}]
        lappend out [list $b $t $w]
    }
    return $out
}

# ==================================================================
# Pages and content
# ==================================================================

# Page objects in reading order: list of {pageValue resourcesDict}.
proc ::tclutils::tupdftext::_pages {doc} {
    upvar #0 $doc D
    set root ""
    # trailer dictionaries and cross-reference streams
    set i 0
    while {[set p [string first trailer $D(data) $i]] >= 0} {
        lassign [_parse $D(data) [expr {$p + 7}]] t
        if {[lindex $t 0] eq "d"} {
            if {[_dget $doc [lindex $t 1] Encrypt] ne ""} { set D(encrypted) 1 }
            set r [_dget $doc [lindex $t 1] Root]
            if {$r ne ""} { set root $r }
        }
        set i [expr {$p + 7}]
    }
    foreach num [_objectsWith $doc /XRef] {
        set d [_dictOf [_obj $doc $num]]
        if {[_dget $doc $d Type] ne {N XRef}} continue
        if {[_dget $doc $d Encrypt] ne ""} { set D(encrypted) 1 }
        set r [_dget $doc $d Root]
        if {$r ne ""} { set root $r }
    }
    if {$root eq ""} {
        foreach num [_objectsWith $doc /Catalog] {
            set v [_obj $doc $num]
            if {[_dget $doc [_dictOf $v] Type] eq {N Catalog}} { set root $v }
        }
    }
    set out {}
    set rd [_dictOf $root]
    set pagesRoot [_dget $doc $rd Pages]
    if {$pagesRoot ne ""} {
        set seen {}
        _walk $doc $pagesRoot {} out seen 0
    }
    if {[llength $out] == 0} {
        # damaged tree: every /Type /Page object, in file order
        set nums {}
        foreach {s num} $D(starts) { lappend nums $num }
        foreach num [lsort -unique -integer $nums] {
            set v [_obj $doc $num]
            if {[_dget $doc [_dictOf $v] Type] eq {N Page}} {
                lappend out [list $v [_dictOf [_dget $doc [_dictOf $v] Resources]]]
            }
        }
    }
    return $out
}

proc ::tclutils::tupdftext::_walk {doc node res outVar seenVar depth} {
    upvar 1 $outVar out $seenVar seen
    if {$depth > 64} return
    if {[lindex $node 0] eq "r"} {
        if {[lindex $node 1] in $seen} return
        lappend seen [lindex $node 1]
    }
    set v [_res $doc $node]
    set d [_dictOf $v]
    set r [_dget $doc $d Resources]
    if {$r ne ""} { set res [_dictOf $r] }
    set type [lindex [_dget $doc $d Type] 1]
    set kids [_dget $doc $d Kids]
    if {$type eq "Pages" || ($type eq "" && [lindex $kids 0] eq "a")} {
        foreach k [lindex $kids 1] {
            _walk $doc $k $res out seen [expr {$depth + 1}]
        }
    } else {
        lappend out [list $v $res]
    }
}

proc ::tclutils::tupdftext::_mul {m n} {
    lassign $m a b c d e f
    lassign $n A B C D E F
    return [list [expr {$a*$A + $b*$C}] [expr {$a*$B + $b*$D}] \
                 [expr {$c*$A + $d*$C}] [expr {$c*$B + $d*$D}] \
                 [expr {$e*$A + $f*$C + $E}] [expr {$e*$B + $f*$D + $F}]]
}

# Text of one page.
proc ::tclutils::tupdftext::_pageText {doc page res} {
    upvar #0 $doc D
    set d [_dictOf $page]
    set c [_dget $doc $d Contents]
    set data ""
    if {[lindex $c 0] eq "stream"} {
        if {![catch {_streamData $doc $c} s]} { set data $s }
    } elseif {[lindex $c 0] eq "a"} {
        foreach x [lindex $c 1] {
            set sv [_res $doc $x]
            if {[lindex $sv 0] eq "stream" && ![catch {_streamData $doc $sv} s]} {
                append data $s "\n"
            }
        }
    }
    set st [dict create out "" lastX "" lastY "" lastSize 0 fontsSeen {}]
    set st [_run $doc $data $res {1 0 0 1 0 0} $st 0]
    return [_clean [dict get $st out]]
}

# Interpret a content stream. st carries the output and the last position.
proc ::tclutils::tupdftext::_run {doc data res ctm st depth} {
    upvar #0 $doc D
    variable maxFormDepth
    set fonts [_dictOf [_dget $doc $res Font]]
    set xobjs [_dictOf [_dget $doc $res XObject]]
    set gstack {}
    set tm {1 0 0 1 0 0}; set tlm $tm
    set tc 0; set tw 0; set th 1.0; set tl 0; set trise 0
    set font ""; set fsize 0
    set ops {}
    set i 0
    set n [string length $data]
    while {$i < $n} {
        lassign [_parse $data $i] v i
        if {$v eq ""} { if {$i >= $n} break; continue }
        if {[lindex $v 0] ne "op"} { lappend ops $v; continue }
        set op [lindex $v 1]
        switch -- $op {
            q  { lappend gstack [list $ctm $tc $tw $th $tl $font $fsize $trise] }
            Q  {
                if {[llength $gstack]} {
                    lassign [lindex $gstack end] ctm tc tw th tl font fsize trise
                    set gstack [lrange $gstack 0 end-1]
                }
            }
            cm {
                if {[llength $ops] >= 6} {
                    set m [lmap x [lrange $ops end-5 end] { _num $x 0 }]
                    set ctm [_mul $m $ctm]
                }
            }
            BT { set tm {1 0 0 1 0 0}; set tlm $tm }
            ET {}
            Tf {
                set fname [lindex [lindex $ops end-1] 1]
                set fsize [_num [lindex $ops end] 0]
                set font ""
                foreach {k fv} $fonts {
                    if {$k eq $fname} { set font [_font $doc $fv]; break }
                }
            }
            Tc { set tc [_num [lindex $ops end] 0] }
            Tw { set tw [_num [lindex $ops end] 0] }
            Tz { set th [expr {[_num [lindex $ops end] 100] / 100.0}] }
            TL { set tl [_num [lindex $ops end] 0] }
            Ts { set trise [_num [lindex $ops end] 0] }
            Td - TD {
                set tx [_num [lindex $ops end-1] 0]; set ty [_num [lindex $ops end] 0]
                if {$op eq "TD"} { set tl [expr {-$ty}] }
                set tlm [_mul [list 1 0 0 1 $tx $ty] $tlm]; set tm $tlm
            }
            Tm {
                if {[llength $ops] >= 6} {
                    set tlm [lmap x [lrange $ops end-5 end] { _num $x 0 }]; set tm $tlm
                }
            }
            T* { set tlm [_mul [list 1 0 0 1 0 [expr {-$tl}]] $tlm]; set tm $tlm }
            Tj - ' - {"} - TJ {
                if {$op eq "'" || $op eq {"}} {
                    if {$op eq {"} && [llength $ops] >= 3} {
                        set tw [_num [lindex $ops end-2] 0]; set tc [_num [lindex $ops end-1] 0]
                    }
                    set tlm [_mul [list 1 0 0 1 0 [expr {-$tl}]] $tlm]; set tm $tlm
                }
                if {$font eq ""} { set font [dict create name ? subtype ? twoByte 0 \
                    spaces {} uni {} enc [_stdEnc] widths {} dw 500 scale 0.001 mapped 0] }
                set arg [lindex $ops end]
                if {[lindex $arg 0] eq "a"} {
                    set items [lindex $arg 1]
                } else {
                    set items [list $arg]
                }
                set scale [dict get $font scale]
                foreach it $items {
                    if {[lindex $it 0] eq "n"} {
                        set adj [lindex $it 1]
                        set dx [expr {-$adj * $scale * $fsize * $th}]
                        set tm [_mul [list 1 0 0 1 $dx 0] $tm]
                        continue
                    }
                    if {[lindex $it 0] ne "s"} continue
                    set glyphs [_glyphs $font [lindex $it 1]]
                    if {[llength $glyphs] == 0} continue
                    # position where this run starts, in device space
                    set trm [_mul [list $fsize 0 0 [expr {$fsize}] 0 $trise] [_mul $tm $ctm]]
                    lassign $trm ra rb rc rd x y
                    set size [expr {hypot($rc, $rd)}]
                    if {$size <= 0} { set size [expr {max(abs($fsize), 1)}] }
                    set text ""
                    foreach g $glyphs {
                        lassign $g code t w
                        append text $t
                        set adv [expr {$w * $scale * $fsize + $tc}]
                        if {$code == 32 && ![dict get $font twoByte]} { set adv [expr {$adv + $tw}] }
                        set tm [_mul [list 1 0 0 1 [expr {$adv * $th}] 0] $tm]
                    }
                    set end [_mul [list $fsize 0 0 $fsize 0 $trise] [_mul $tm $ctm]]
                    set st [_emit $st $text $x $y [lindex $end 4] [lindex $end 5] $size]
                }
            }
            Do {
                set xname [lindex [lindex $ops end] 1]
                foreach {k xv} $xobjs {
                    if {$k ne $xname} continue
                    if {[lindex $xv 0] eq "r"} {
                        set ref [lindex $xv 1]
                    } else {
                        set ref ""
                    }
                    set xs [_res $doc $xv]
                    if {[lindex $xs 0] ne "stream"} break
                    set xd [lindex $xs 1]
                    if {[_dget $doc $xd Subtype] ne {N Form}} break
                    if {$depth >= $maxFormDepth} break
                    if {$ref ne "" && $ref in [dict get $st fontsSeen]} break
                    set fm [_dget $doc $xd Matrix]
                    set m {1 0 0 1 0 0}
                    if {[lindex $fm 0] eq "a"} {
                        set m [lmap x [lindex $fm 1] { _num [_res $doc $x] 0 }]
                    }
                    set xr [_dget $doc $xd Resources]
                    if {$xr ne ""} {
                        set xres [_dictOf $xr]
                    } else {
                        set xres $res
                    }
                    if {[catch {_streamData $doc $xs} xdata]} break
                    if {$ref ne ""} { dict lappend st fontsSeen $ref }
                    set st [_run $doc $xdata $xres [_mul $m $ctm] $st [expr {$depth + 1}]]
                    if {$ref ne ""} {
                        dict set st fontsSeen [lrange [dict get $st fontsSeen] 0 end-1]
                    }
                    break
                }
            }
            BI {
                # inline image: skip its data up to EI
                set idp [string first ID $data $i]
                if {$idp < 0} { set i $n; break }
                if {[regexp -indices -start [expr {$idp + 3}] {[\0\t\n\f\r ]EI(?=[\0\t\n\f\r ]|$)} $data m]} {
                    set i [expr {[lindex $m 1] + 1}]
                } else {
                    set i $n
                }
            }
        }
        set ops {}
    }
    return $st
}

proc ::tclutils::tupdftext::_stdEnc {} {
    variable encTables
    _initTables
    return $encTables(StandardEncoding)
}

# Append a run of text, with a space or line break from its position.
proc ::tclutils::tupdftext::_emit {st text x y ex ey size} {
    if {$text eq ""} { return $st }
    set out [dict get $st out]
    set lx [dict get $st lastX]; set ly [dict get $st lastY]
    if {$lx ne "" && $out ne ""} {
        set ref [expr {max($size, [dict get $st lastSize], 1.0)}]
        set dy [expr {abs($y - $ly)}]
        set dx [expr {$x - $lx}]
        if {$dy > 0.5 * $ref} {
            append out \n
        } elseif {$dx > 0.15 * $ref || $dx < -2.0 * $ref} {
            # "*\[ \n\]" in quotes: in braces \n would be the two characters
            if {![string match "*\[ \n\]" $out] && ![string match { *} $text]} { append out " " }
        }
    }
    append out $text
    dict set st out $out
    dict set st lastX $ex
    dict set st lastY $ey
    dict set st lastSize $size
    return $st
}

# Ligatures to letters, soft hyphen away, blanks folded, lines trimmed.
proc ::tclutils::tupdftext::_clean {s} {
    set s [string map {ﬀ ff ﬁ fi ﬂ fl ﬃ ffi ﬄ ffl
        ﬅ st ﬆ st ­ ""   " " \t " " \r ""} $s]
    set lines {}
    foreach l [split $s \n] {
        set l [string trim [regsub -all { {2,}} $l " "]]
        if {$l ne ""} { lappend lines $l }
    }
    return [join $lines \n]
}

# ==================================================================
# Public API
# ==================================================================

proc ::tclutils::tupdftext::_opts {args spec} {
    set o $spec
    if {[llength $args] % 2} {
        _err OPTION "missing value for option \"[lindex $args end]\""
    }
    foreach {k v} $args {
        if {![dict exists $spec $k]} {
            _err OPTION "unknown option \"$k\"\nKnown: [join [lsort [dict keys $spec]] { }]"
        }
        dict set o $k $v
    }
    return $o
}

# pages file ?-notext error|empty?
#   List with the text of every page, in page order.
proc ::tclutils::tupdftext::pages {file args} {
    set o [_opts $args {-notext error}]
    if {[dict get $o -notext] ni {error empty}} {
        _err OPTION "-notext must be error or empty"
    }
    set doc [_open $file]
    try {
        set pl [_pages $doc]
        upvar #0 $doc D
        if {[info exists D(encrypted)]} {
            _err ENCRYPTED "encrypted PDF (not supported): $file"
        }
        if {[llength $pl] == 0} { _err FORMAT "no pages found: $file" }
        set out {}
        set any 0
        foreach p $pl {
            lassign $p page res
            set t [_pageText $doc $page $res]
            if {$t ne ""} { set any 1 }
            lappend out $t
        }
        if {!$any && [dict get $o -notext] eq "error"} {
            _err NOTEXT "no text on any of [llength $pl] pages (scan or images only?): $file"
        }
        return $out
    } finally {
        _close $doc
    }
}

# text file ?-separator s? ?-notext error|empty?
#   All pages as one string, pages separated by -separator (default "\f").
proc ::tclutils::tupdftext::text {file args} {
    set o [_opts $args {-separator \f -notext error}]
    return [join [pages $file -notext [dict get $o -notext]] [dict get $o -separator]]
}

# summary file
#   dict: pages, encrypted, version, fonts (list of dicts name subtype
#   toUnicode), textPages, unmapped (glyphs without Unicode)
proc ::tclutils::tupdftext::summary {file} {
    set doc [_open $file]
    try {
        upvar #0 $doc D
        set pl [_pages $doc]
        set version ""
        regexp {%PDF-(\d+\.\d+)} [string range $D(data) 0 1023] -> version
        set enc [info exists D(encrypted)]
        set textPages 0
        set unmapped 0
        if {!$enc} {
            foreach p $pl {
                lassign $p page res
                set t [_pageText $doc $page $res]
                if {$t ne ""} { incr textPages }
                incr unmapped [regexp -all � $t]
            }
        }
        set fonts {}
        foreach k [lsort [array names D font,*]] {
            set f $D($k)
            lappend fonts [dict create name [dict get $f name] \
                subtype [dict get $f subtype] toUnicode [dict get $f mapped]]
        }
        return [dict create pages [llength $pl] encrypted $enc version $version \
            fonts $fonts textPages $textPages unmapped $unmapped]
    } finally {
        _close $doc
    }
}

package provide tclutils::tupdftext 0.2
