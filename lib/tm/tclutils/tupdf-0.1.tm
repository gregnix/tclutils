# tclutils::tupdf -- minimal PDF structure inspector (read-only)
# Description: minimal PDF structure inspector (read-only)
# Category: Data · structures & formats
# Tcl 8.6+
#
# Pragmatic pure-Tcl tools for inspecting/debugging PDF files: header version,
# object and page counts, the trailer dictionary, document Info metadata, a few
# structural flags, and raw extraction of an individual indirect object.
#
# It scans the file's tokens rather than fully resolving the cross-reference
# table. That makes it robust on uncompressed / linearized / QDF (qpdf -qdf)
# files. Objects stored inside compressed object streams (/ObjStm) or pages
# hidden behind cross-reference streams are NOT visible to a raw scan -- counts
# are then lower bounds. It is an inspector, not a full PDF parser.

package require Tcl 8.6-
package require tclutils::common 0.1

namespace eval ::tclutils {}
namespace eval ::tclutils::tupdf {
    namespace export version objects object trailer metadata summary zugferd
    variable version 0.1
}

proc ::tclutils::tupdf::_read {pdfFile} {
    return [::tclutils::common::readBinaryFile $pdfFile]
}

# PDF header version, e.g. "1.7". Errors if the file has no %PDF- header.
proc ::tclutils::tupdf::version {pdfFile} {
    set data [_read $pdfFile]
    if {![regexp {%PDF-(\d+\.\d+)} [string range $data 0 1024] -> v]} {
        return -code error -errorcode {TCLUTILS TUPDF FORMAT} \
            "no %PDF- header found in $pdfFile"
    }
    return $v
}

# Sorted, unique list of indirect object numbers found by scanning "N G obj".
proc ::tclutils::tupdf::objects {pdfFile} {
    set data [_read $pdfFile]
    set ids {}
    foreach {whole num gen} \
            [regexp -all -inline {(\d+)\s+(\d+)\s+obj(?![A-Za-z])} $data] {
        lappend ids $num
    }
    return [lsort -integer -unique $ids]
}

# Raw text of indirect object $id (the "id G obj ... endobj" span).
# Works for objects present uncompressed in the file body.
proc ::tclutils::tupdf::object {pdfFile id} {
    if {![string is integer -strict $id]} {
        return -code error -errorcode {TCLUTILS TUPDF ARG} \
            "object id must be an integer, got \"$id\""
    }
    set data [_read $pdfFile]
    if {![regexp -indices "(?:^|\[^0-9])($id\\s+\\d+\\s+obj)" $data -> sub]} {
        return -code error -errorcode {TCLUTILS TUPDF NOTFOUND} \
            "object $id not found (it may live in a compressed object stream)"
    }
    set start [lindex $sub 0]
    set end [string first "endobj" $data $start]
    if {$end < 0} {
        return -code error -errorcode {TCLUTILS TUPDF FORMAT} \
            "no endobj after object $id"
    }
    return [string range $data $start [expr {$end + 5}]]
}

# The trailer dictionary text (last trailer wins for incremental updates).
# Returns "" for files that use a cross-reference stream instead of a trailer
# keyword.
proc ::tclutils::tupdf::trailer {pdfFile} {
    set data [_read $pdfFile]
    set last ""
    foreach {whole dict} [regexp -all -inline {trailer\s*(<<(?:[^<>]|<[^<]|>[^>])*>>)} $data] {
        set last $dict
    }
    return $last
}

proc ::tclutils::tupdf::_pageCount {data} {
    set n 0
    foreach m [regexp -all -inline {/Type\s*/Page(?![A-Za-z])} $data] {
        incr n
    }
    return $n
}

proc ::tclutils::tupdf::_decodeHexString {hex} {
    regsub -all {[^0-9A-Fa-f]} $hex "" hex
    if {[string length $hex] % 2 == 1} { append hex 0 }
    set bytes [binary decode hex $hex]
    # UTF-16BE if it starts with a BOM, otherwise pass the bytes through.
    if {[string range $bytes 0 1] eq "\xFE\xFF"} {
        binary scan [string range $bytes 2 end] S* shorts
        set s ""
        foreach code $shorts { append s [format %c [expr {$code & 0xFFFF}]] }
        return $s
    }
    return $bytes
}

proc ::tclutils::tupdf::_pdfNameToText {name} {
    return [string map {#20 { } #2F / #2B + #28 ( #29 ) #3C < #3E > #5B [ #5D ] #23 #} $name]
}

proc ::tclutils::tupdf::_collectAttachmentNames {data} {
    set names {}
    foreach {whole val} [regexp -all -inline {/(?:F|UF)\s*\(([^)\\]+(?:\\.[^)\\]*)*)\)} $data] {
        lappend names [_decodeLiteralString $val]
    }
    foreach {whole hex} [regexp -all -inline {/(?:F|UF)\s*<([0-9A-Fa-f\s]+)>} $data] {
        catch {lappend names [_decodeHexString $hex]}
    }
    foreach {whole val} [regexp -all -inline {/Desc\s*\(([^)\\]+(?:\\.[^)\\]*)*)\)} $data] {
        lappend names [_decodeLiteralString $val]
    }
    set out {}
    foreach n $names {
        if {[regexp -nocase {(?:zugferd|factur-x|facturx|invoice).*\.xml$|^xref/.*\.xml$} $n]} {
            lappend out $n
        }
    }
    return [lsort -unique $out]
}

proc ::tclutils::tupdf::_collectInvoiceMimes {data} {
    set mimes {}
    foreach {whole lit} [regexp -all -inline {/Subtype\s*\(([^)]+)\)} $data] {
        if {[regexp -nocase {vnd\.zugferd|pdf\+xml|factur-x} $lit]} {
            lappend mimes $lit
        }
    }
    foreach {whole name} [regexp -all -inline {/Subtype\s*/([^\s/>]+)} $data] {
        set norm [_pdfNameToText $name]
        if {[regexp -nocase {vnd\.zugferd|pdf\+xml|factur-x} $norm]} {
            lappend mimes $norm
        }
    }
    return [lsort -unique $mimes]
}

# Heuristic ZUGFeRD / Factur-X detection from raw PDF bytes. Works on
# uncompressed attachments visible in the file body; not a conformance check.
proc ::tclutils::tupdf::zugferd {pdfFile} {
    set data [_read $pdfFile]
    set embedded [regexp {/(?:EmbeddedFile|EmbeddedFiles|Filespec)\y} $data]
    set associated [regexp {/AF\y|/AFRelationship} $data]
    set names [_collectAttachmentNames $data]
    set mimes [_collectInvoiceMimes $data]
    set zugferdMarker [regexp -nocase {zugferd} $data]
    set facturMarker [regexp -nocase {factur-x|facturx} $data]
    set xmlMarker [regexp -nocase {CrossIndustryInvoice|urn:ferd:pdf-invoice|ram:?Invoice} $data]

    set hints {}
    if {$embedded} { lappend hints embeddedFile }
    if {$associated} { lappend hints associatedFiles }
    if {$zugferdMarker} { lappend hints zugferdMarker }
    if {$facturMarker} { lappend hints facturXMarker }
    if {$xmlMarker} { lappend hints invoiceXmlContent }

    set detected 0
    if {[llength $names] > 0 || [llength $mimes] > 0} {
        set detected 1
    } elseif {($embedded || $associated) && ($xmlMarker || $zugferdMarker || $facturMarker)} {
        set detected 1
    }

    set profile ""
    if {$detected} {
        if {$facturMarker || [regexp -nocase factur $data]} {
            set profile factur-x
        } elseif {$zugferdMarker || [llength $mimes] > 0} {
            set profile zugferd
        } else {
            set profile unknown
        }
    }

    return [dict create \
        detected $detected \
        profile $profile \
        attachmentNames $names \
        mimeTypes $mimes \
        hints $hints]
}

proc ::tclutils::tupdf::_decodeLiteralString {s} {
    # Handle the common PDF literal-string escapes; leave the rest verbatim.
    return [string map {\\( ( \\) ) \\\\ \\ \\n \n \\r \r \\t \t} $s]
}

# Document Info metadata as a dict (Title, Author, Subject, Keywords, Creator,
# Producer, CreationDate, ModDate -- whichever are present). Looks up the Info
# object referenced by the trailer; falls back to scanning for the Info dict.
proc ::tclutils::tupdf::metadata {pdfFile} {
    set data [_read $pdfFile]
    set src ""
    if {[regexp {/Info\s+(\d+)\s+\d+\s+R} [trailer $pdfFile] -> infoId]} {
        catch {set src [object $pdfFile $infoId]}
    }
    if {$src eq ""} {
        # Fallback: an object that looks like an Info dictionary.
        set src [regexp -inline {<<[^<]*?/(?:Producer|Creator|Title)[^>]*?>>} $data]
    }
    set result [dict create]
    foreach key {Title Author Subject Keywords Creator Producer CreationDate ModDate} {
        if {[regexp "/$key\\s*\\(((?:\[^()\\\\]|\\\\.)*)\\)" $src -> val]} {
            dict set result $key [_decodeLiteralString $val]
        } elseif {[regexp "/$key\\s*<(\[0-9A-Fa-f\\s\]+)>" $src -> val]} {
            dict set result $key [_decodeHexString $val]
        }
    }
    return $result
}

# Compact summary dict: version, size, objects, pages, encrypted, linearized,
# acroform, plus any Info metadata under the same dict.
proc ::tclutils::tupdf::summary {pdfFile} {
    set data [_read $pdfFile]
    set tr [trailer $pdfFile]
    set encrypted [expr {[regexp {/Encrypt\y} $tr] || \
        ($tr eq "" && [regexp {/Encrypt\s+\d+\s+\d+\s+R} $data])}]
    set result [dict create \
        version    [version $pdfFile] \
        size       [string length $data] \
        objects    [llength [objects $pdfFile]] \
        pages      [_pageCount $data] \
        encrypted  [expr {$encrypted ? 1 : 0}] \
        linearized [expr {[regexp {/Linearized\y} [string range $data 0 4096]] ? 1 : 0}] \
        acroform   [expr {[regexp {/AcroForm\y} $data] ? 1 : 0}]]
    set zf [zugferd $pdfFile]
    dict set result zugferdDetected [dict get $zf detected]
    if {[dict get $zf profile] ne ""} {
        dict set result zugferdProfile [dict get $zf profile]
    }
    return [dict merge $result [metadata $pdfFile]]
}

package provide tclutils::tupdf 0.1
