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
# Scope: paragraph text documents. It is NOT a full ODF toolkit -- for styles,
# tables, images, spreadsheets, etc. use a dedicated ODF library.

package require Tcl 8.6-
package require tclutils::common 0.1
package require tclutils::tuzip 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tuodf {
    namespace export createText text paragraphs part parts
    variable version 0.1
    # Fixed timestamp for reproducible builds and a valid (non-zero) DOS date.
    variable epoch 1262304000
    variable mimeText "application/vnd.oasis.opendocument.text"
}

proc ::tclutils::tuodf::_xmlEscape {s} {
    return [string map {& &amp; < &lt; > &gt; \" &quot; ' &apos;} $s]
}

proc ::tclutils::tuodf::_xmlUnescape {s} {
    return [string map {&lt; < &gt; > &quot; \" &apos; ' &amp; &} $s]
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

# Return the document's paragraphs as a list of plain-text strings.
# Lightweight extractor: handles text:p with inline spans, tabs, spaces and
# line breaks. It does not descend into tables or other block structures.
proc ::tclutils::tuodf::paragraphs {odtFile} {
    set xml [part $odtFile content.xml]
    # Normalize self-closing empty paragraphs to an explicit open/close pair so
    # a single, unambiguous pattern handles every paragraph.
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

# Return the document's plain text (paragraphs joined by newlines).
proc ::tclutils::tuodf::text {odtFile} {
    return [join [paragraphs $odtFile] \n]
}

package provide tclutils::tuodf 0.1
