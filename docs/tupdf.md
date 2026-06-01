# tclutils::tupdf

Read-only PDF structure inspector in pure Tcl.

`tupdf` scans PDF files for common structural information: header version,
object ids, page markers, trailer text, metadata, and raw uncompressed objects.
It is a lightweight inspector, not a full PDF parser.

## Package

```tcl
package require tclutils::tupdf 0.1
```

## API

```tcl
::tclutils::tupdf::version pdfFile
::tclutils::tupdf::summary pdfFile
::tclutils::tupdf::metadata pdfFile
::tclutils::tupdf::trailer pdfFile
::tclutils::tupdf::objects pdfFile
::tclutils::tupdf::object pdfFile id
::tclutils::tupdf::zugferd pdfFile
```

## Example

```tcl
package require tclutils::tupdf

puts [::tclutils::tupdf::version doc.pdf]
puts [::tclutils::tupdf::summary doc.pdf]
puts [::tclutils::tupdf::zugferd doc.pdf]
puts [::tclutils::tupdf::object doc.pdf 3]
```

## ZUGFeRD / Factur-X

`zugferd` applies lightweight heuristics on the raw file bytes:

- embedded files (`/EmbeddedFile`, `/Filespec`, `/AF`)
- invoice XML attachment names (`ZUGFeRD-invoice.xml`, `factur-x.xml`, …)
- MIME markers (`application/vnd.zugferd…`, `application/pdf+xml`)
- invoice XML snippets (`CrossIndustryInvoice`, …)

Returns a dict: `detected`, `profile` (`zugferd`, `factur-x`, `unknown`, or `""`),
`attachmentNames`, `mimeTypes`, `hints`.

This is **not** a PDF/A-3 or EN 16931 conformance check. Attachments inside
compressed object streams may be invisible to the scan.

`summary` adds `zugferdDetected` (and `zugferdProfile` when detected).

## Limitations

Objects stored inside compressed object streams and pages hidden behind xref
streams are not fully resolved. Counts can therefore be lower bounds on modern
compressed PDFs. For deep inspection, convert to QDF with qpdf or use a full PDF
parser/debugging tool.
