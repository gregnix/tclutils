# tclutils::tusort

Sort helpers similar to Unix `sort`, implemented in pure Tcl.

## Package

```tcl
package require tclutils::tusort 0.1
```

## Commands

```tcl
::tclutils::tusort::sortList items ?options...?
::tclutils::tusort::text text ?options...?
::tclutils::tusort::file path ?options...?
```

## Options

- `-numeric 1` sort numerically using Tcl's real comparison
- `-integer 1` sort as integers
- `-real 1` sort as real numbers
- `-dictionary 1` dictionary-style sorting
- `-nocase 1` case-insensitive sorting
- `-reverse 1` reverse/decreasing order
- `-unique 1` remove duplicate values during sorting

## Examples

```tcl
set sorted [::tclutils::tusort::sortList {banana apple cherry}]
set sorted [::tclutils::tusort::file names.txt -dictionary 1 -nocase 1]
set sorted [::tclutils::tusort::file numbers.txt -numeric 1 -reverse 1]
```
