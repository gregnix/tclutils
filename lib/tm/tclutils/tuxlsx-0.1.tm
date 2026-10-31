# tclutils::tuxlsx -- minimal Excel (XLSX, Office Open XML) table helpers
# Description: minimal XLSX helpers: write one sheet of rows, read sheets back as rows
# Category: Data · structures & formats
# Tcl 8.6+
#
# Write a simple workbook with one sheet and read the cell values of any
# workbook back, the spreadsheet counterpart of tudocx. Pure Tcl: the
# container goes through tuzip, the XML parts come from string templates,
# reading is a small scanner (no XML parser, no tdom).
#
#   ::tclutils::tuxlsx::writeRows xlsxFile rows ?-sheet NAME? ?-numbers auto|0?
#                                 ?-title T? ?-creator C?
#   ::tclutils::tuxlsx::sheets xlsxFile           -> sheet names, in order
#   ::tclutils::tuxlsx::rows xlsxFile ?-sheet NAME|INDEX?  -> list of rows
#   ::tclutils::tuxlsx::text xlsxFile             -> all sheets as text
#   ::tclutils::tuxlsx::part xlsxFile name / parts xlsxFile
#
# writeRows: ROWS is a list of rows, each a list of cell values. With
# -numbers auto (default) a value that looks like a decimal number
# (-12, 3.5, 1e3) is stored as a number, everything else as text; -numbers 0
# stores every cell as text. Text is written inline (no shared strings).
#
# rows: values as Excel stores them -- shared and inline strings as text,
# numbers as written in the file (a date is its serial number, a percentage
# its fraction), booleans 1/0, formulas their last computed value, errors
# as text (#DIV/0!). Gaps are filled with "": a row is as long as its last
# cell, missing rows are empty lists. Formatting is not read.
#
# text: the rows of every sheet, cells joined by \t, rows by \n, sheets
# separated by an empty line -- for search and quick looks.
#
# Errors: {TCLUTILS TUXLSX SHEET name} unknown sheet; {TCLUTILS TUXLSX VALUE}
# a sheet name Excel does not accept; {TCLUTILS TUXLSX PART name} a missing
# part; {TCLUTILS COMMON OPTION ...} bad options. A missing or damaged ZIP is
# reported by tuzip.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tuzip 0.2

namespace eval ::tclutils {}
namespace eval ::tclutils::tuxlsx {
    namespace export writeRows sheets rows text part parts
    variable version 0.1
    variable epoch 1262304000
    variable nsMain "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    variable nsRel "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
}

proc ::tclutils::tuxlsx::_err {reason detail msg} {
    return -code error -level 2 -errorcode [list TCLUTILS TUXLSX $reason {*}$detail] $msg
}

proc ::tclutils::tuxlsx::_xmlEscape {s} {
    return [string map {& &amp; < &lt; > &gt; \" &quot; ' &apos;} $s]
}

# A numeric character reference as a character; a code point past
# Unicode, NUL or too long a number is U+FFFD (up to 2026-10-30 a big
# number broke off the reading under Tcl 8.6).
proc ::tclutils::tuxlsx::_cp {digits base} {
    if {[string length $digits] > 8} { return \uFFFD }
    if {$base == 16} { set n [scan $digits %x] } else { set n [scan $digits %d] }
    if {$n <= 0 || $n > 0x10FFFF} { return \uFFFD }
    return [format %c $n]
}

proc ::tclutils::tuxlsx::_xmlUnescape {s} {
    if {[string first & $s] < 0} { return $s }
    set out ""
    while {[regexp -indices {&(#x[0-9A-Fa-f]+|#[0-9]+|lt|gt|quot|apos|amp);} $s m e]} {
        append out [string range $s 0 [expr {[lindex $m 0] - 1}]]
        set ent [string range $s {*}$e]
        switch -glob -- $ent {
            lt   { append out < }
            gt   { append out > }
            quot { append out \" }
            apos { append out ' }
            amp  { append out & }
            #x*  { append out [_cp [string range $ent 2 end] 16] }
            default { append out [_cp [string range $ent 1 end] 10] }
        }
        set s [string range $s [expr {[lindex $m 1] + 1}] end]
    }
    return $out$s
}

# Column letters for 1-based index N: 1 -> A, 27 -> AA.
proc ::tclutils::tuxlsx::_col {n} {
    set s ""
    while {$n > 0} {
        set r [expr {($n - 1) % 26}]
        set s [format %c [expr {65 + $r}]]$s
        set n [expr {($n - 1) / 26}]
    }
    return $s
}

# 1-based column index of letters: A -> 1, AA -> 27.
proc ::tclutils::tuxlsx::_colIndex {letters} {
    set n 0
    foreach c [split [string toupper $letters] ""] {
        set n [expr {$n * 26 + [scan $c %c] - 64}]
    }
    return $n
}

# Attributes of a start tag as a dict (name -> unescaped value).
proc ::tclutils::tuxlsx::_attrs {tag} {
    set d [dict create]
    foreach {- k v} [regexp -all -inline {([\w:.-]+)\s*=\s*"([^"]*)"} $tag] {
        dict set d $k [_xmlUnescape $v]
    }
    foreach {- k v} [regexp -all -inline {([\w:.-]+)\s*=\s*'([^']*)'} $tag] {
        dict set d $k [_xmlUnescape $v]
    }
    return $d
}

# ---- writing ----------------------------------------------------------------

proc ::tclutils::tuxlsx::_checkSheetName {name} {
    set bad 0
    foreach ch [list \[ \] : * ? / \\] {
        if {[string first $ch $name] >= 0} { set bad 1 }
    }
    if {$bad || $name eq "" || [string length $name] > 31
            || [string index $name 0] eq "'" || [string index $name end] eq "'"} {
        _err VALUE {} "bad sheet name \"$name\": 1 to 31 characters, none of \[ \] : * ? / \\, not starting or ending with '"
    }
}

proc ::tclutils::tuxlsx::_sheetXml {rows numbers} {
    variable nsMain
    set data ""
    set r 0
    foreach row $rows {
        incr r
        set cells ""
        set c 0
        foreach v $row {
            incr c
            if {$v eq ""} continue
            set ref [_col $c]$r
            if {$numbers && [regexp {^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$} $v]} {
                append cells "<c r=\"$ref\"><v>$v</v></c>"
            } else {
                append cells "<c r=\"$ref\" t=\"inlineStr\"><is><t xml:space=\"preserve\">[_xmlEscape $v]</t></is></c>"
            }
        }
        if {$cells ne ""} { append data "  <row r=\"$r\">$cells</row>\n" }
    }
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<worksheet xmlns=\"$nsMain\">
 <sheetData>
$data </sheetData>
</worksheet>
"
}

proc ::tclutils::tuxlsx::_workbookXml {sheet} {
    variable nsMain
    variable nsRel
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<workbook xmlns=\"$nsMain\" xmlns:r=\"$nsRel\">
 <sheets>
  <sheet name=\"[_xmlEscape $sheet]\" sheetId=\"1\" r:id=\"rId1\"/>
 </sheets>
</workbook>
"
}

proc ::tclutils::tuxlsx::_workbookRelsXml {} {
    set od http://schemas.openxmlformats.org/officeDocument/2006/relationships
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">
 <Relationship Id=\"rId1\" Type=\"$od/worksheet\" Target=\"worksheets/sheet1.xml\"/>
 <Relationship Id=\"rId2\" Type=\"$od/styles\" Target=\"styles.xml\"/>
</Relationships>
"
}

# The smallest style sheet Excel accepts without a repair message.
proc ::tclutils::tuxlsx::_stylesXml {} {
    variable nsMain
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<styleSheet xmlns=\"$nsMain\">
 <fonts count=\"1\"><font><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>
 <fills count=\"2\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill></fills>
 <borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
 <cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>
 <cellXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/></cellXfs>
 <cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles>
</styleSheet>
"
}

proc ::tclutils::tuxlsx::_contentTypesXml {} {
    set x application/vnd.openxmlformats-officedocument.spreadsheetml
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">
 <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>
 <Default Extension=\"xml\" ContentType=\"application/xml\"/>
 <Override PartName=\"/xl/workbook.xml\" ContentType=\"$x.sheet.main+xml\"/>
 <Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"$x.worksheet+xml\"/>
 <Override PartName=\"/xl/styles.xml\" ContentType=\"$x.styles+xml\"/>
 <Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>
 <Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>
</Types>
"
}

proc ::tclutils::tuxlsx::_relsXml {} {
    set od http://schemas.openxmlformats.org/officeDocument/2006/relationships
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">
 <Relationship Id=\"rId1\" Type=\"$od/officeDocument\" Target=\"xl/workbook.xml\"/>
 <Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/>
 <Relationship Id=\"rId3\" Type=\"$od/extended-properties\" Target=\"docProps/app.xml\"/>
</Relationships>
"
}

proc ::tclutils::tuxlsx::_coreXml {opts} {
    set extra ""
    if {[dict get $opts -title] ne ""} {
        append extra " <dc:title>[_xmlEscape [dict get $opts -title]]</dc:title>\n"
    }
    if {[dict get $opts -creator] ne ""} {
        append extra " <dc:creator>[_xmlEscape [dict get $opts -creator]]</dc:creator>\n"
    }
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">
$extra</cp:coreProperties>
"
}

proc ::tclutils::tuxlsx::_appXml {} {
    variable version
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\">
 <Application>tclutils::tuxlsx $version</Application>
</Properties>
"
}

proc ::tclutils::tuxlsx::writeRows {xlsxFile rows args} {
    variable epoch
    set opts [::tclutils::common::parseOptions \
        [dict create -sheet Sheet1 -numbers auto -title "" -creator ""] {*}$args]
    set sheet [dict get $opts -sheet]
    _checkSheetName $sheet
    set numbers [expr {[dict get $opts -numbers] eq "auto" ? 1
        : [::tclutils::common::ensureBoolean [dict get $opts -numbers] -numbers]}]
    set members {}
    foreach {name xml} [list \
            {[Content_Types].xml}       [_contentTypesXml] \
            _rels/.rels                 [_relsXml] \
            xl/workbook.xml             [_workbookXml $sheet] \
            xl/_rels/workbook.xml.rels  [_workbookRelsXml] \
            xl/styles.xml               [_stylesXml] \
            xl/worksheets/sheet1.xml    [_sheetXml $rows $numbers] \
            docProps/core.xml           [_coreXml $opts] \
            docProps/app.xml            [_appXml]] {
        lappend members [dict create name $name content [encoding convertto utf-8 $xml]]
    }
    ::tclutils::tuzip::createMembers $xlsxFile $members -mtime $epoch
    return $xlsxFile
}

# ---- reading ----------------------------------------------------------------

proc ::tclutils::tuxlsx::part {xlsxFile name} {
    if {$name ni [parts $xlsxFile]} {
        _err PART [list $name] "no part \"$name\" in \"$xlsxFile\""
    }
    return [encoding convertfrom utf-8 [::tclutils::tuzip::readMember $xlsxFile $name]]
}

# A part as XML for the scanner: element names without the prefix of the
# SpreadsheetML and relationship namespaces. Excel writes them without a
# prefix; the Open XML SDK (.NET) writes <x:sheet>, <x:c> ...
proc ::tclutils::tuxlsx::_xml {xlsxFile name} {
    set xml [part $xlsxFile $name]
    foreach {- p} [regexp -all -inline {xmlns:([\w.-]+)\s*=\s*"(?:http://schemas\.openxmlformats\.org/(?:spreadsheetml/2006/main|package/2006/relationships)|http://purl\.oclc\.org/ooxml/spreadsheetml/main)"} $xml] {
        regsub -all "<(/?)[string map {. \\.} $p]:" $xml {<\1} xml
    }
    return $xml
}

proc ::tclutils::tuxlsx::parts {xlsxFile} {
    return [::tclutils::tuzip::names $xlsxFile]
}

# Elements NAME of XML as a list of {attrs inner}; inner is "" for an empty
# element. A small scanner instead of one regexp: a Tcl RE with .*? is not
# reliably shortest.
proc ::tclutils::tuxlsx::_elements {xml name} {
    set out {}
    set pos 0
    set n [string length $name]
    while {[set i [string first "<$name" $xml $pos]] >= 0} {
        set after [string index $xml [expr {$i + $n + 1}]]
        if {![string is space $after] && $after ni {> /}} {
            set pos [expr {$i + $n + 1}]
            continue
        }
        set e [string first > $xml $i]
        if {$e < 0} break
        set tag [string range $xml $i $e]
        if {[string index $xml [expr {$e - 1}]] eq "/"} {
            lappend out [list [_attrs $tag] ""]
            set pos [expr {$e + 1}]
            continue
        }
        set close [string first "</$name>" $xml $e]
        if {$close < 0} break
        lappend out [list [_attrs $tag] [string range $xml [expr {$e + 1}] [expr {$close - 1}]]]
        set pos [expr {$close + $n + 3}]
    }
    return $out
}

# Text of all <t> inside XML (a shared string or an inline string); the
# phonetic runs (rPh) are left out.
proc ::tclutils::tuxlsx::_tText {xml} {
    regsub -all {<rPh\y(?:[^<]|<(?!/rPh>))*</rPh>} $xml "" xml
    set t ""
    foreach el [_elements $xml t] { append t [_xmlUnescape [lindex $el 1]] }
    return $t
}

# Resolve a relationship target of the workbook (relative to xl/, or absolute).
proc ::tclutils::tuxlsx::_target {target} {
    if {[string index $target 0] eq "/"} { return [string range $target 1 end] }
    set parts {}
    foreach p [split xl/$target /] {
        if {$p eq ".."} { set parts [lrange $parts 0 end-1] } elseif {$p ne "."} { lappend parts $p }
    }
    return [join $parts /]
}

# Sheets as a list of {name part}, in workbook order.
proc ::tclutils::tuxlsx::_sheetParts {xlsxFile} {
    set wb [_xml $xlsxFile xl/workbook.xml]
    set rels [dict create]
    if {"xl/_rels/workbook.xml.rels" in [parts $xlsxFile]} {
        foreach el [_elements [_xml $xlsxFile xl/_rels/workbook.xml.rels] Relationship] {
            set a [lindex $el 0]
            if {[dict exists $a Id] && [dict exists $a Target]} {
                dict set rels [dict get $a Id] [_target [dict get $a Target]]
            }
        }
    }
    set out {}
    set k 0
    foreach el [_elements $wb sheet] {
        incr k
        set a [lindex $el 0]
        # if, not expr: expr would turn a name like 007 into 7
        set name Sheet$k
        if {[dict exists $a name]} { set name [dict get $a name] }
        set rid ""
        dict for {key v} $a { if {[string match *:id $key]} { set rid $v } }
        set p xl/worksheets/sheet$k.xml
        if {[dict exists $rels $rid]} { set p [dict get $rels $rid] }
        lappend out [list $name $p]
    }
    return $out
}

proc ::tclutils::tuxlsx::sheets {xlsxFile} {
    return [lmap s [_sheetParts $xlsxFile] {lindex $s 0}]
}

proc ::tclutils::tuxlsx::_sharedStrings {xlsxFile} {
    if {"xl/sharedStrings.xml" ni [parts $xlsxFile]} { return {} }
    set out {}
    foreach el [_elements [_xml $xlsxFile xl/sharedStrings.xml] si] {
        lappend out [_tText [lindex $el 1]]
    }
    return $out
}

proc ::tclutils::tuxlsx::_sheetRows {xml shared} {
    set rows {}
    set rn 0
    foreach rowEl [_elements $xml row] {
        lassign $rowEl ra inner
        set r [expr {[dict exists $ra r] ? [dict get $ra r] : $rn + 1}]
        # rows Excel left out are empty
        while {[llength $rows] < $r - 1} { lappend rows {} }
        set rn $r
        set row {}
        set cn 0
        foreach cEl [_elements $inner c] {
            lassign $cEl ca cinner
            set c [expr {$cn + 1}]
            if {[dict exists $ca r] && [regexp {^([A-Za-z]+)} [dict get $ca r] -> letters]} {
                set c [_colIndex $letters]
            }
            set cn $c
            set t n
            if {[dict exists $ca t]} { set t [dict get $ca t] }
            set v ""
            set vEl [_elements $cinner v]
            if {[llength $vEl]} { set v [_xmlUnescape [lindex $vEl 0 1]] }
            switch -- $t {
                s {
                    if {[string is integer -strict $v] && $v >= 0 && $v < [llength $shared]} {
                        set v [lindex $shared $v]
                    }
                }
                inlineStr {
                    set is [_elements $cinner is]
                    # if, not expr: expr would turn the text 007 into 7
                    set v ""
                    if {[llength $is]} { set v [_tText [lindex $is 0 1]] }
                }
            }
            while {[llength $row] < $c - 1} { lappend row "" }
            lappend row $v
        }
        lappend rows $row
    }
    return $rows
}

proc ::tclutils::tuxlsx::rows {xlsxFile args} {
    set opts [::tclutils::common::parseOptions [dict create -sheet ""] {*}$args]
    set want [dict get $opts -sheet]
    set sp [_sheetParts $xlsxFile]
    if {$want eq ""} {
        set hit [lindex $sp 0]
    } elseif {[set i [lsearch -exact -index 0 $sp $want]] >= 0} {
        set hit [lindex $sp $i]
    } elseif {[string is integer -strict $want] && $want >= 1 && $want <= [llength $sp]} {
        set hit [lindex $sp [expr {$want - 1}]]
    } else {
        _err SHEET [list $want] "no sheet \"$want\" in \"$xlsxFile\": [join [lmap s $sp {lindex $s 0}] {, }]"
    }
    if {$hit eq ""} { return {} }
    return [_sheetRows [_xml $xlsxFile [lindex $hit 1]] [_sharedStrings $xlsxFile]]
}

proc ::tclutils::tuxlsx::text {xlsxFile} {
    set shared [_sharedStrings $xlsxFile]
    set out {}
    foreach s [_sheetParts $xlsxFile] {
        set rows [_sheetRows [_xml $xlsxFile [lindex $s 1]] $shared]
        lappend out [join [lmap r $rows {join $r \t}] \n]
    }
    return [join $out \n\n]
}

package provide tclutils::tuxlsx 0.1
