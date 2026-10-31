# tclutils::tudocx -- minimal Word (DOCX, Office Open XML) text helpers
# Description: minimal DOCX text helpers: write paragraphs, read the text back
# Category: Data · structures & formats
# Tcl 8.6+
#
# Create and read simple Word documents (.docx), the counterpart of tuodf for
# Office Open XML. Pure Tcl: the container is assembled through tuzip, the XML
# parts come from string templates, and reading is a lightweight text
# extractor (no XML parser, no tdom).
#
#   ::tclutils::tudocx::createText docxFile paragraphs ?-title T? ?-creator C?
#   ::tclutils::tudocx::paragraphs docxFile   -> list of paragraph texts
#   ::tclutils::tudocx::text docxFile         -> paragraphs joined by \n
#   ::tclutils::tudocx::part docxFile name    -> a container part as text
#   ::tclutils::tudocx::parts docxFile        -> member names
#
# paragraphs reads the main document part (found through _rels/.rels, usually
# word/document.xml): every w:p in document order, headings, list items and
# table cells included. A tab is \t, a line break \n (a page or column
# break is no text). Any prefix of the WordprocessingML namespace is
# read, also the default namespace. Deleted text of tracked
# changes (w:delText) and field codes (w:instrText) are left out. Headers,
# footers, footnotes and comments live in other parts and are not read.
#
# Scope: paragraph text. It is NOT a Word toolkit -- no styles, tables,
# images or numbering when writing.
#
# Errors: {TCLUTILS TUDOCX PART name} when the document has no main part;
# a missing or damaged ZIP is reported by tuzip.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tuzip 0.2

namespace eval ::tclutils {}
namespace eval ::tclutils::tudocx {
    namespace export createText text paragraphs part parts
    variable version 0.1
    # Fixed timestamp for reproducible output (same as tuodf).
    variable epoch 1262304000
    variable nsW "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    variable nsRel "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    variable nsPkgRel "http://schemas.openxmlformats.org/package/2006/relationships"
}

proc ::tclutils::tudocx::_xmlEscape {s} {
    return [string map {& &amp; < &lt; > &gt; \" &quot; ' &apos;} $s]
}

# A numeric character reference as a character; a code point past
# Unicode, NUL or too long a number is U+FFFD (up to 2026-10-30 a big
# number broke off the reading under Tcl 8.6).
proc ::tclutils::tudocx::_cp {digits base} {
    if {[string length $digits] > 8} { return \uFFFD }
    if {$base == 16} { set n [scan $digits %x] } else { set n [scan $digits %d] }
    if {$n <= 0 || $n > 0x10FFFF} { return \uFFFD }
    return [format %c $n]
}

# Entities of an XML text: the five named ones and numeric references.
proc ::tclutils::tudocx::_xmlUnescape {s} {
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

# One paragraph of the body: \t becomes w:tab, \n w:br.
proc ::tclutils::tudocx::_paragraphXml {p} {
    if {$p eq ""} { return "<w:p/>" }
    set runs ""
    set first 1
    foreach line [split $p \n] {
        if {!$first} { append runs "<w:br/>" }
        set first 0
        set tfirst 1
        foreach piece [split $line \t] {
            if {!$tfirst} { append runs "<w:tab/>" }
            set tfirst 0
            if {$piece ne ""} {
                append runs "<w:t xml:space=\"preserve\">[_xmlEscape $piece]</w:t>"
            }
        }
    }
    return "<w:p><w:r>$runs</w:r></w:p>"
}

proc ::tclutils::tudocx::_documentXml {paragraphs} {
    variable nsW
    variable nsRel
    set body ""
    if {[llength $paragraphs] == 0} { set paragraphs [list ""] }
    foreach p $paragraphs { append body "  [_paragraphXml $p]\n" }
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<w:document xmlns:w=\"$nsW\" xmlns:r=\"$nsRel\">
 <w:body>
$body  <w:sectPr/>
 </w:body>
</w:document>
"
}

proc ::tclutils::tudocx::_contentTypesXml {} {
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">
 <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>
 <Default Extension=\"xml\" ContentType=\"application/xml\"/>
 <Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>
 <Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>
 <Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>
</Types>
"
}

proc ::tclutils::tudocx::_relsXml {} {
    variable nsPkgRel
    set od http://schemas.openxmlformats.org/officeDocument/2006/relationships
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<Relationships xmlns=\"$nsPkgRel\">
 <Relationship Id=\"rId1\" Type=\"$od/officeDocument\" Target=\"word/document.xml\"/>
 <Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/>
 <Relationship Id=\"rId3\" Type=\"$od/extended-properties\" Target=\"docProps/app.xml\"/>
</Relationships>
"
}

proc ::tclutils::tudocx::_coreXml {opts} {
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

proc ::tclutils::tudocx::_appXml {} {
    variable version
    return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\">
 <Application>tclutils::tudocx $version</Application>
</Properties>
"
}

# Create a minimal Word document at $docxFile from a list of paragraph
# strings. Options: -title and -creator (docProps/core.xml).
proc ::tclutils::tudocx::createText {docxFile paragraphs args} {
    variable epoch
    set opts [::tclutils::common::parseOptions \
        [dict create -title "" -creator ""] {*}$args]
    set members {}
    foreach {name xml} [list \
            {[Content_Types].xml} [_contentTypesXml] \
            _rels/.rels           [_relsXml] \
            word/document.xml     [_documentXml $paragraphs] \
            docProps/core.xml     [_coreXml $opts] \
            docProps/app.xml      [_appXml]] {
        lappend members [dict create name $name content [encoding convertto utf-8 $xml]]
    }
    ::tclutils::tuzip::createMembers $docxFile $members -mtime $epoch
    return $docxFile
}

# The decoded (UTF-8) text of a container part, e.g. word/document.xml.
proc ::tclutils::tudocx::part {docxFile name} {
    return [encoding convertfrom utf-8 [::tclutils::tuzip::readMember $docxFile $name]]
}

proc ::tclutils::tudocx::parts {docxFile} {
    return [::tclutils::tuzip::names $docxFile]
}

# Name of the main document part: the officeDocument relationship of
# _rels/.rels, else word/document.xml.
proc ::tclutils::tudocx::_mainPart {docxFile} {
    set names [parts $docxFile]
    if {"_rels/.rels" in $names} {
        set rels [part $docxFile _rels/.rels]
        foreach {- tag} [regexp -all -inline {(<Relationship\y[^>]*>)} $rels] {
            if {[regexp {Type="[^"]*/officeDocument"} $tag]
                    && [regexp {Target="([^"]*)"} $tag -> target]} {
                set target [string trimleft $target /]
                if {$target in $names} { return $target }
            }
        }
    }
    if {"word/document.xml" in $names} { return word/document.xml }
    return -code error -errorcode {TCLUTILS TUDOCX PART word/document.xml} \
        "no main document part in \"$docxFile\""
}

# The document's paragraphs as plain-text strings, in document order.
# The main part with its WordprocessingML elements as w:NAME, whatever
# prefix the file uses: Word writes w:, other tools another prefix or the
# default namespace.
proc ::tclutils::tudocx::_wXml {xml} {
    set ns {(?:http://schemas\.openxmlformats\.org/wordprocessingml/2006/main|http://purl\.oclc\.org/ooxml/wordprocessingml/main)}
    foreach {- p} [regexp -all -inline "xmlns:(\[\\w.-\]+)\\s*=\\s*\"$ns\"" $xml] {
        if {$p ne "w"} {
            regsub -all "<(/?)[string map {. \\.} $p]:" $xml {<\1w:} xml
        }
    }
    if {[regexp "xmlns\\s*=\\s*\"$ns\"" $xml]} {
        # default namespace: unprefixed element names belong to it
        regsub -all {<(/?)([A-Za-z_][\w.-]*)([\s/>])} $xml {<\1w:\2\3} xml
    }
    return $xml
}

proc ::tclutils::tudocx::paragraphs {docxFile} {
    set xml [_wXml [part $docxFile [_mainPart $docxFile]]]
    # leave out what is not text of the document
    foreach el {w:pPr w:rPr w:delText w:instrText} {
        regsub -all "<$el\\y\[^>\]*/>" $xml "" xml
        # (?:[^<]|<(?!/el>))* and not .*?: in a Tcl RE the first quantifier
        # sets greedy or not for the whole match
        regsub -all "<$el\\y\[^>\]*>(?:\[^<\]|<(?!/$el>))*</$el>" $xml "" xml
    }
    # tab and break as text pieces, so one pattern collects all text
    regsub -all {<w:tab\y[^>]*/>} $xml {<w:t>\&#9;</w:t>} xml
    # a page or column break is not text; a plain break is a line break
    regsub -all {<w:br\y[^>]*\ytype\s*=\s*["'](?:page|column)["'][^>]*/>} $xml "" xml
    regsub -all {<w:(?:br|cr)\y[^>]*/>} $xml {<w:t>\&#10;</w:t>} xml
    regsub -all {<w:noBreakHyphen\y[^>]*/>} $xml {<w:t>-</w:t>} xml
    regsub -all {<w:p\y[^>]*/>} $xml {<w:p></w:p>} xml
    set result {}
    foreach {- inner} [regexp -all -inline {<w:p(?:\s[^>]*)?>((?:[^<]|<(?!/w:p>))*)</w:p>} $xml] {
        set t ""
        foreach {- piece} [regexp -all -inline {<w:t(?:\s[^>]*)?>([^<]*)</w:t>} $inner] {
            append t $piece
        }
        lappend result [_xmlUnescape $t]
    }
    return $result
}

proc ::tclutils::tudocx::text {docxFile} {
    return [join [paragraphs $docxFile] \n]
}

package provide tclutils::tudocx 0.1
