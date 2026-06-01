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

`-words 1` is a small convenience mode. It is not a full formatter.
