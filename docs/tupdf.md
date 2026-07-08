# tclutils::tupdf

Read-only PDF structure inspector in pure Tcl.

`tupdf` scans PDF files for common structural information: header version,
object ids, page markers, trailer text, metadata, and raw objects. Since **0.2**
it also inflates compressed object streams (`/ObjStm`) with the built-in `zlib`
and reads the trailer from a cross-reference stream (`/Type /XRef`), so objects,
pages and metadata hidden inside them are resolved too. It is still a
lightweight inspector, not a full PDF parser.

## Package

```tcl
package require tclutils::tupdf 0.2
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

This is **not** a PDF/A-3 or EN 16931 conformance check. Since 0.2 attachments
referenced from compressed object streams are resolved; attachment *contents*
inside encrypted streams remain invisible.

`summary` adds `zugferdDetected` (and `zugferdProfile` when detected).

## Compressed PDFs (0.2)

Modern PDFs pack most objects into zlib-compressed **object streams**
(`/Type /ObjStm`) and replace the classic trailer with a **cross-reference
stream** (`/Type /XRef`). `tupdf` 0.2 handles both:

- `/ObjStm` streams are inflated (`zlib`) and their embedded objects are exposed
  as normal `N 0 obj … endobj` text, so `objects`, `object`, `metadata` and the
  page count in `summary` see them.
- `trailer` falls back to the `/Type /XRef` dictionary (`/Root`, `/Info`,
  `/Size`) when there is no `trailer` keyword.

As a result, `pages` and `objects` are exact on Flate-compressed PDFs, not just
lower bounds. No external tool (qpdf) is required.

## Limitations

The binary cross-reference table is not decoded (its plaintext dictionary is
enough for the trailer). Object streams with a PNG/TIFF **predictor** are rare
and skipped -- counts then fall back to a lower bound. **Encrypted** streams are
not decrypted, and attachments inside encrypted streams stay invisible. For deep
inspection, convert to QDF with qpdf or use a full PDF parser.
