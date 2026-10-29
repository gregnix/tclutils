# tclutils::tufold

`tufold` folds long lines to a fixed width, similar to Unix `fold`.

## Usage

```tcl
package require tclutils::tufold

puts [::tclutils::tufold::text $text -width 80]
puts [::tclutils::tufold::file README.md -width 72 -words 1]
```

## Commands

```tcl
::tclutils::tufold::foldLine line ?options?
::tclutils::tufold::text text ?options?
::tclutils::tufold::file path ?options?
```

## Options

```text
-width n           maximum line width, default 80
-words boolean     prefer breaking at blanks when possible
```

`-words 1` is a small convenience mode. It is not a full formatter. A line
longer than `-width` is broken at the last blank at or before column
`-width`+1. The blanks at the break are dropped: trailing blanks of the line
and leading blanks of the next one. A word longer than `-width` is cut hard.

Difference from Unix `fold -s`: `fold -s` keeps the blanks, breaks after the
last blank within the width and keeps leading blanks of the next line. For
`"ab   cd"` with width 3, `fold -s` gives `"ab "`, `"  "`, `"cd"`; `tufold`
gives `ab`, `cd`.

## Errors

`-width` not a positive integer raises `{TCLUTILS COMMON INTEGER -width}`,
`-words` not a boolean `{TCLUTILS COMMON BOOLEAN -words}`, an unknown option
`{TCLUTILS COMMON OPTION -name}`.

## Line ends

`text` and `file` return text that ends with LF exactly when the input does:
`"b\nJörg\n"` gives a result with final LF, `"b\nJörg"` one without, like
`tuhead`, `tutail` and `tunl`. Versions before 0.3 dropped the final LF.
