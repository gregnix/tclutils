# tclutils::tumd

Small dependency-free Markdown helpers for Tcl.

`tumd` is intentionally not a full Markdown system. It provides a practical
CommonMark subset for scripts and CI: Markdown-to-HTML fragments, ATX heading
extraction, table-of-contents generation, and YAML front matter splitting.

## Package

```tcl
package require tclutils::tumd 0.1
```

## API

```tcl
::tclutils::tumd::toHtml markdown
::tclutils::tumd::headings markdown
::tclutils::tumd::toc markdown
::tclutils::tumd::frontmatter markdown
```

## Example

```tcl
package require tclutils::tumd

set md {# Title

A **short** paragraph.}
puts [::tclutils::tumd::toHtml $md]
puts [::tclutils::tumd::toc $md]
```

## Supported subset

Blocks:

- ATX headings (`#` to `######`)
- paragraphs
- fenced code blocks using backticks or tildes
- blockquotes
- flat ordered and unordered lists
- horizontal rules

Inline constructs:

- code spans
- bold and italic
- links and images
- autolinks
- hard line breaks with two trailing spaces

## Limits

`tumd` does not implement nested lists, Setext headings, GFM tables,
reference-style links, raw HTML passthrough, or a full Markdown AST. For larger
Markdown workflows, use the mdstack/docir toolchain.
