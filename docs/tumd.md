# tclutils::tumd

Small dependency-free Markdown helpers for Tcl.

`tumd` covers the Markdown that READMEs, manuals and help files use, for
scripts and CI: Markdown-to-HTML fragments with GitHub-style tables, heading
extraction, table-of-contents generation, and YAML front matter splitting.

## Package

```tcl
package require tclutils::tumd 0.3
```

## API

```tcl
::tclutils::tumd::toHtml markdown ?option value ...?
::tclutils::tumd::headings markdown
::tclutils::tumd::toc markdown
::tclutils::tumd::frontmatter markdown
::tclutils::tumd::parse markdown ?-lines 0|1?
::tclutils::tumd::inline text ?refs? ?notes?
::tclutils::tumd::paragraph lines ?refs? ?notes?
::tclutils::tumd::unescape html
```

| command | returns |
|---|---|
| `toHtml` | HTML fragment, or a whole page with `-page 1` (options below) |
| `headings` | `{level text}` for each top-level heading |
| `toc` | Markdown list of links to the headings |
| `frontmatter` | `{frontMatterText body}` |
| `parse` | dict: the blocks of the document, its link definitions and footnotes (below) |
| `inline` | HTML of the inline Markdown of one block, with the document's definitions |
| `paragraph` | HTML of a paragraph given as its lines (hard breaks as `<br>`) |
| `unescape` | text of such HTML with the entities decoded |

## toHtml options

| option | meaning |
|---|---|
| `-page bool` | a complete page: doctype, `<head>` with title and style, `<body>` |
| `-title text` | page title; default the front matter `title:`, else the first heading |
| `-css text` | style sheet of the page; default a small one, `""` for none |
| `-lang code` | `lang` attribute of the page |
| `-linkmap {from to ...}` | suffix pairs for relative links, e.g. `{.md .html}` |
| `-headingoffset n` | add `n` to every heading level (at most 6) |

```tcl
set html [::tclutils::tumd::toHtml $md -page 1 -lang de -linkmap {.md .html}]
```

Errors: `{TCLUTILS TUMD OPTION name}` for an unknown option,
`{TCLUTILS TUMD VALUE}` for a bad value.

## Blocks for viewers and editors

`parse` returns a dict:

| key | content |
|---|---|
| `blocks` | the blocks of the document, the same `toHtml` writes (below) |
| `refs` | link reference definitions, for `inline` and `paragraph` |
| `notes` | footnotes (key -> number), for `inline` and `paragraph` |

With `-lines 1` also:

| key | content |
|---|---|
| `lines` | `{first last}` for each top-level block; lines counted from 1 after the front matter, trailing blank lines not included |
| `definitions` | `{key first last}` for each link reference definition (not a block) |
| `offset` | number of lines of the front matter, `0` without one |

CRLF and a lone CR count as one line end. Nested blocks (list items,
quote and footnote contents) lie within the lines of their top-level
block. A footnote definition is a top-level block (`footnote`).

| block | content |
|---|---|
| `h level text id` | heading; `id` as in `toHtml` |
| `p lines` | paragraph lines |
| `code lang text` | fenced or indented code |
| `hr` | horizontal rule |
| `quote blocks` | block quote |
| `list ordered start loose items marker` | list; item `{task blocks}`, task `""`, `open` or `done`; marker `-`, `*`, `+` or `.`, `)` |
| `table aligns header rows` | table; align `left`, `center`, `right` or `""` |
| `footnote key number blocks` | footnote definition |
| `comment text` | HTML comment (not shown) |

Text in blocks is still Markdown. `inline` (or `paragraph` for `p`) turns
it into HTML; the definitions are passed explicitly, so several documents
can be open at the same time:

```tcl
set d [::tclutils::tumd::parse $md]
foreach b [dict get $d blocks] {
    if {[lindex $b 0] eq "p"} {
        puts [::tclutils::tumd::paragraph [lindex $b 1] \
            [dict get $d refs] [dict get $d notes]]
    }
}
```

Without `refs` and `notes`, reference links and footnote references stay
text. `tkutils::tkumdview` draws a document this way.

## HTML comments

Raw HTML is escaped, with one exception: HTML comments are hidden, both
as a block (a line starting with `<!--`, up to the line with `-->`) and
inside text (`Vom <!--f:datum-->12.11.2026<!--/f-->` shows
`Vom 12.11.2026`). In code they stay text.

## What is supported

Blocks:

- ATX headings (`#` to `######`) and setext headings (a line underlined
  with `===` or `---`)
- paragraphs
- fenced code blocks using backticks or tildes; indented code (four spaces)
- blockquotes, also with lazy continuation lines
- ordered and unordered lists: nested, items continued on indented lines,
  tight or loose (blank lines between items give `<p>` inside `<li>`),
  start number of an ordered list, task items `- [ ]` and `- [x]`
- GitHub-style tables (see below)
- horizontal rules
- link reference definitions (`[label]: url "title"`), not printed
- footnotes: `[^label]: text`, continued by lines indented four spaces

Inline constructs:

- code spans, also with a backtick inside (``` ``a`b`` ```)
- backslash escapes (`\*`, `\_`, `\|`, ...)
- bold, italic, `~~strikethrough~~`; emphasis may span a line break
- links and images, inline with optional title (`[t](url "title")`) and
  by reference (`[t][label]`, `[t][]`, `[label]`); a URL may contain
  parentheses (`https://de.wikipedia.org/wiki/Foo_(Bar)`)
- autolinks for URLs and e-mail addresses (`<https://...>`, `<a@b.de>`)
- bare URLs (`https://...`, `www....`) as links; trailing punctuation and
  an unbalanced `)` stay outside
- entities: named (`&copy;`, `&auml;`, `&euro;`, ...) and numeric
  (`&#228;`, `&#x20AC;`); an unknown name and a single `&` are escaped
- footnote references `[^label]`
- hard line breaks with two trailing spaces or a trailing backslash

`headings` and `toc` list the top-level headings, ATX and setext. CRLF
line ends are read like LF.

## Footnotes

```markdown
Text with a note[^q].

[^q]: The note.
    A second line.
```

Footnotes are numbered in the order of their definitions. A reference
becomes `<sup id="fnref-1"><a href="#fn-1">1</a></sup>`; the notes follow at
the end as `<section class="footnotes">` with an `<ol>`, each `<li id="fn-1">`
with a link back. A reference without a definition stays text.

## Tables

A table is a header row and a separator row, then body rows until a blank
line or another block:

```markdown
| Status | Betrag |
|:-------|-------:|
| bezahlt | 1,00 |
```

The separator sets the alignment (`:--` left, `:-:` center, `--:` right),
written as `style="text-align:..."` on `<th>` and `<td>`. Inline markup works
in cells, `\|` is a literal pipe, short rows are filled with empty cells.
Lines with pipes but no separator row stay a paragraph.

## Heading anchors

`toHtml` gives each heading an `id`, `toc` links to it. The anchor is made
as on GitHub: lower case, `*` and backticks removed, everything but letters,
digits, `_`, `-` and blanks removed, blanks become `-`. Letters of every
script stay (`Jörg` -> `jörg`, `Über` -> `über`). A repeated anchor gets
`-1`, `-2`, ... (0.2; 0.1 kept only `a-z` and `0-9`, so `Jörg` and `Jrg` both
became `jrg`).

## Limits

Raw HTML in the input is escaped, not passed through (comments are hidden), so the output is safe
to embed. Not supported: definition lists, heading attributes (`{#id}`), and
the finer CommonMark rules for emphasis and list indentation.
