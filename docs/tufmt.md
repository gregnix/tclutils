# tclutils::tufmt

Reflow text paragraphs to a target width, like `fmt(1)`. Paragraphs are
separated by blank lines; within a paragraph whitespace is collapsed and words
are greedily wrapped. Each paragraph keeps the leading indentation of its first
line, and runs of blank lines collapse to a single separator.

## API

```tcl
set wrapped [::tclutils::tufmt::reflow $text -width 72]
```

Commands:

- `reflow text ?-width n?` — reflowed text (default width 75).
- `reflowFile path ?-width n?` — reflow a file's contents.

A tab in the leading indent counts as one column. The width must be a positive
integer (`{TCLUTILS COMMON INTEGER -width}` otherwise).
