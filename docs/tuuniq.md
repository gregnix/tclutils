# tclutils::tuuniq

Uniq helpers similar to Unix `uniq`, implemented in pure Tcl.

Important: `uniq` removes only adjacent duplicate lines. Sort first if you want to remove all duplicates independent of position.

## Package

```tcl
package require tclutils::tuuniq 0.2
```

## Commands

```tcl
::tclutils::tuuniq::uniqList items ?options...?
::tclutils::tuuniq::text text ?options...?
::tclutils::tuuniq::file path ?options...?
::tclutils::tuuniq::adjacentCount items ?options...?
::tclutils::tuuniq::count items ?options...?
::tclutils::tuuniq::countText text ?options...?
::tclutils::tuuniq::countFile path ?options...?
```

## Options

- `-nocase 1` compare case-insensitively

## Examples

```tcl
set unique [::tclutils::tuuniq::uniqList {a a b a}]
# -> a b a

set counts [::tclutils::tuuniq::countFile names.txt]
```

## Line ends

`text` and `file` return text that ends with LF exactly when the input does:
`"b\nJörg\n"` gives a result with final LF, `"b\nJörg"` one without, like
`tuhead`, `tutail` and `tunl`. Versions before 0.2 dropped the final LF.
