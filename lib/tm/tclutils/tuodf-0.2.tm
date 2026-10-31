# tclutils::tuodf -- minimal OpenDocument (ODF) text helpers
# Description: minimal OpenDocument (ODF) text helpers
# Category: Data · structures & formats
# Tcl 8.6+
#
# Create and read simple ODF text documents (.odt). Pure Tcl: the container is
# assembled through tuzip (mimetype first and STORED, as ODF requires), the XML
# parts are emitted from validated string templates, and reading is a
# lightweight paragraph-text extractor (no XML parser / no tdom dependency).
#
# Spreadsheets (.ods, 0.2): sheets lists the table names, rows gives one
# table as a list of rows, each a list of cell texts (the text:p of a cell,
# joined by \n -- what the cell shows, not the stored value). A merged-away
# cell is empty. Repeated empty cells and rows at the end of a row or table
# are dropped; a repeated cell or row with content counts at most repeatMax
# (1000) times, so a file cannot blow up the memory.
#
# Scope: paragraph text documents. It is NOT a full ODF toolkit -- for styles,
# tables, images, spreadsheets, etc. use a dedicated ODF library.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tuzip 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuodf {
    namespace export createText text paragraphs part parts sheets rows
    # a repeated cell or row with content counts at most this often
    variable repeatMax 1000
    variable version 0.2
    # Fixed timestamp for reproducible builds and a valid (non-zero) DOS date.
    variable epoch 1262304000
    variable mimeText "application/vnd.oasis.opendocument.text"
}

proc ::tclutils::tuodf::_xmlEscape {s} {
    return [string map {& &amp; < &lt; > &gt; \" &quot; ' &apos;} $s]
}

# A numeric character reference as a character; a code point past
# Unicode, NUL or too long a number is U+FFFD (up to 2026-10-30 a big
# number broke off the reading under Tcl 8.6).
proc ::tclutils::tuodf::_cp {digits base} {
    if {[string length $digits] > 8} { return \uFFFD }
    if {$base == 16} { set n [scan $digits %x] } else { set n [scan $digits %d] }
    if {$n <= 0 || $n > 0x10FFFF} { return \uFFFD }
    return [format %c $n]
}

# Entities of an XML text: the five named ones and numeric references
# (up to 2026-10-30 only the named ones; "&#252;" stayed as it was).
proc ::tclutils::tuodf::_xmlUnescape {s} {
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

proc ::tclutils::tuodf::_writeBytes {path bytes} {
    set fh [open $path wb]
    try {
        fconfigure $fh -translation binary -encoding iso8859-1
        puts -nonewline $fh $bytes
    } finally {
        close $fh
    }
    return $path
}


proc ::tclutils::tuodf::_rmTree {path} {
    if {![file exists $path]} { return }
    if {![file isdirectory $path]} {
        file delete -force $path
        return
    }
    foreach child [glob -nocomplain -directory $path * .*] {
        set tail [file tail $child]
        if {$tail in {. ..}} { continue }
        _rmTree $child
    }
    file delete -force $path
}

proc ::tclutils::tuodf::_tempDir {} {
    set ch [file tempfile path]
    close $ch
    file delete $path
    set dir ${path}.d
    file mkdir $dir
    return $dir
}

proc ::tclutils::tuodf::_contentXml {paragraphs} {
    set body ""
    if {[llength $paragraphs] == 0} {
        set body "   <text:p/>\n"
    } else {
        foreach p $paragraphs {
            if {$p eq ""} {
                append body "   <text:p/>\n"
            } else {
                append body "   <text:p>[_xmlEscape $p]</text:p>\n"
            }
        }
    }
    return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<office:document-content\
 xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\"\
 xmlns:text=\"urn:oasis:names:tc:opendocument:xmlns:text:1.0\"\
 office:version=\"1.3\">
 <office:body>
  <office:text>
$body  </office:text>
 </office:body>
</office:document-content>
"
}

proc ::tclutils::tuodf::_stylesXml {} {
    return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<office:document-styles\
 xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\"\
 xmlns:style=\"urn:oasis:names:tc:opendocument:xmlns:style:1.0\"\
 office:version=\"1.3\">
 <office:styles/>
 <office:automatic-styles/>
 <office:master-styles/>
</office:document-styles>
"
}

proc ::tclutils::tuodf::_metaXml {opts} {
    variable version
    set extra ""
    if {[dict get $opts -title] ne ""} {
        append extra "  <dc:title>[_xmlEscape [dict get $opts -title]]</dc:title>\n"
    }
    if {[dict get $opts -creator] ne ""} {
        append extra "  <dc:creator>[_xmlEscape [dict get $opts -creator]]</dc:creator>\n"
    }
    return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<office:document-meta\
 xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\"\
 xmlns:meta=\"urn:oasis:names:tc:opendocument:xmlns:meta:1.0\"\
 xmlns:dc=\"http://purl.org/dc/elements/1.1/\"\
 office:version=\"1.3\">
 <office:meta>
  <meta:generator>tclutils::tuodf $version</meta:generator>
$extra </office:meta>
</office:document-meta>
"
}

proc ::tclutils::tuodf::_manifestXml {} {
    variable mimeText
    return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<manifest:manifest\
 xmlns:manifest=\"urn:oasis:names:tc:opendocument:xmlns:manifest:1.0\"\
 manifest:version=\"1.3\">
 <manifest:file-entry manifest:full-path=\"/\" manifest:version=\"1.3\" manifest:media-type=\"$mimeText\"/>
 <manifest:file-entry manifest:full-path=\"content.xml\" manifest:media-type=\"text/xml\"/>
 <manifest:file-entry manifest:full-path=\"styles.xml\" manifest:media-type=\"text/xml\"/>
 <manifest:file-entry manifest:full-path=\"meta.xml\" manifest:media-type=\"text/xml\"/>
</manifest:manifest>
"
}

proc ::tclutils::tuodf::_writePart {dir name text} {
    set path [file join $dir $name]
    file mkdir [file dirname $path]
    _writeBytes $path [encoding convertto utf-8 $text]
    return $path
}

# Create a minimal ODF text document at $odtFile from a list of paragraph
# strings. Options: -title "" and -creator "" (written into meta.xml).
proc ::tclutils::tuodf::createText {odtFile paragraphs args} {
    variable epoch
    variable mimeText
    set opts [::tclutils::common::parseOptions \
        [dict create -title "" -creator ""] {*}$args]

    set dir [_tempDir]
    try {
        # mimetype must be the first archive entry and STORED (uncompressed).
        set mimePath [file join $dir mimetype]
        _writeBytes $mimePath $mimeText
        set p1 [_writePart $dir content.xml [_contentXml $paragraphs]]
        set p2 [_writePart $dir styles.xml [_stylesXml]]
        set p3 [_writePart $dir meta.xml [_metaXml $opts]]
        set p4 [_writePart $dir META-INF/manifest.xml [_manifestXml]]

        # Fixed mtime -> reproducible output and a valid (non-zero) DOS date.
        foreach f [list $mimePath $p1 $p2 $p3 $p4] {
            file mtime $f $epoch
        }

        # -compress 0 keeps every entry STORED; mimetype stays first via order.
        ::tclutils::tuzip::create $odtFile \
            [list $mimePath $p1 $p2 $p3 $p4] -base $dir -compress 0
    } finally {
        _rmTree $dir
    }
    return $odtFile
}

# Return the decoded (UTF-8) text of a container part, e.g. content.xml.
proc ::tclutils::tuodf::part {odtFile name} {
    return [encoding convertfrom utf-8 [::tclutils::tuzip::readMember $odtFile $name]]
}

# Return the list of container member names.
proc ::tclutils::tuodf::parts {odtFile} {
    return [::tclutils::tuzip::names $odtFile]
}

# Return the document's paragraphs as a list of plain-text strings, in
# document order. Lightweight extractor: handles text:p and headings (text:h,
# since 0.2; up to 0.1 they were left out) with inline spans, tabs, spaces
# and line breaks. Paragraphs inside tables, lists and spreadsheet cells
# (.ods) and slides (.odp) are found as well; no other structure is kept.
proc ::tclutils::tuodf::paragraphs {odtFile} {
    return [_paraTexts [part $odtFile content.xml]]
}

# The text of the paragraphs in an XML fragment, in order.
proc ::tclutils::tuodf::_paraTexts {xml} {
    regsub -all {<text:h\y} $xml {<text:p} xml
    regsub -all {</text:h>} $xml {</text:p>} xml
    regsub -all {<text:p\y[^>]*/>} $xml {<text:p></text:p>} xml
    set result {}
    foreach {whole inner} [regexp -all -inline \
            {<text:p\y[^>]*>((?:[^<]|<(?!/text:p>))*)</text:p>} $xml] {
        set t $inner
        regsub -all {<text:tab\y[^>]*/>} $t "\t" t
        regsub -all {<text:line-break\y[^>]*/>} $t "\n" t
        regsub -all {<text:s\y[^>]*/>} $t " " t
        regsub -all {<[^>]*>} $t "" t
        lappend result [_xmlUnescape $t]
    }
    return $result
}

# The tables of content.xml as a list of {name innerXml}.
proc ::tclutils::tuodf::_tables {odsFile} {
    set xml [part $odsFile content.xml]
    set out {}
    foreach {- attrs inner} [regexp -all -inline \
            {<table:table(\s[^>]*)?>((?:[^<]|<(?!/table:table>))*)</table:table>} $xml] {
        set name ""
        regexp {\ytable:name\s*=\s*"([^"]*)"} $attrs -> name
        lappend out [list [_xmlUnescape $name] $inner]
    }
    return $out
}

# A repeat count from the attributes (1 when there is none).
proc ::tclutils::tuodf::_repeat {attrs which} {
    if {[regexp "\\ytable:number-$which-repeated\\s*=\\s*\"(\\d+)\"" $attrs -> n] && $n > 0} {
        return [scan $n %d]
    }
    return 1
}

proc ::tclutils::tuodf::_tableRows {inner} {
    variable repeatMax
    # self-closing rows and cells as open/close pairs; a covered (merged
    # away) cell reads as an empty cell
    regsub -all {<table:table-row(\s[^>]*)?/>} $inner {<table:table-row\1></table:table-row>} inner
    regsub -all {<table:(?:covered-)?table-cell(\s[^>]*)?/>} $inner {<table:table-cell\1></table:table-cell>} inner
    regsub -all {<table:covered-table-cell\y} $inner {<table:table-cell} inner
    regsub -all {</table:covered-table-cell>} $inner {</table:table-cell>} inner
    set rows {}
    set emptyRows 0
    foreach {- rattrs rinner} [regexp -all -inline \
            {<table:table-row(\s[^>]*)?>((?:[^<]|<(?!/table:table-row>))*)</table:table-row>} $inner] {
        set row {}
        set emptyCells 0
        foreach {- cattrs cinner} [regexp -all -inline \
                {<table:table-cell(\s[^>]*)?>((?:[^<]|<(?!/table:table-cell>))*)</table:table-cell>} $rinner] {
            set n [_repeat $cattrs columns]
            set v [join [_paraTexts $cinner] \n]
            if {$v eq ""} { incr emptyCells $n ; continue }
            for {set i 0} {$i < min($emptyCells, $repeatMax)} {incr i} { lappend row "" }
            set emptyCells 0
            for {set i 0} {$i < min($n, $repeatMax)} {incr i} { lappend row $v }
        }
        set n [_repeat $rattrs rows]
        if {![llength $row]} { incr emptyRows $n ; continue }
        for {set i 0} {$i < min($emptyRows, $repeatMax)} {incr i} { lappend rows {} }
        set emptyRows 0
        for {set i 0} {$i < min($n, $repeatMax)} {incr i} { lappend rows $row }
    }
    return $rows
}

# The table (sheet) names of a spreadsheet, in order.
proc ::tclutils::tuodf::sheets {odsFile} {
    return [lmap t [_tables $odsFile] {lindex $t 0}]
}

# One table as a list of rows. -sheet NAME or INDEX (from 1); default the
# first. {TCLUTILS TUODF SHEET name} when there is no such table.
proc ::tclutils::tuodf::rows {odsFile args} {
    set opts [::tclutils::common::parseOptions [dict create -sheet ""] {*}$args]
    set want [dict get $opts -sheet]
    set tables [_tables $odsFile]
    if {$want eq ""} {
        set hit [lindex $tables 0]
    } elseif {[set i [lsearch -exact -index 0 $tables $want]] >= 0} {
        set hit [lindex $tables $i]
    } elseif {[string is integer -strict $want] && $want >= 1 && $want <= [llength $tables]} {
        set hit [lindex $tables [expr {$want - 1}]]
    } else {
        return -code error -errorcode [list TCLUTILS TUODF SHEET $want] \
            "no sheet \"$want\" in \"$odsFile\": [join [lmap t $tables {lindex $t 0}] {, }]"
    }
    if {$hit eq ""} { return {} }
    return [_tableRows [lindex $hit 1]]
}

# Return the document's plain text (paragraphs joined by newlines).
proc ::tclutils::tuodf::text {odtFile} {
    return [join [paragraphs $odtFile] \n]
}

package provide tclutils::tuodf 0.2
