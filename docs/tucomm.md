# tclutils::tucomm

`tucomm` provides a small `comm`-like comparison for sorted line lists or files.
It returns a dictionary with three groups:

```tcl
onlyA  ;# lines only in the first input
onlyB  ;# lines only in the second input
both   ;# lines present in both inputs
```

## Usage

```tcl
package require tclutils::tucomm

set result [::tclutils::tucomm::files a.txt b.txt]
dict get $result onlyA
dict get $result onlyB
dict get $result both
```

## Commands

```tcl
::tclutils::tucomm::compareLines aLines bLines ?options?
::tclutils::tucomm::text aText bText ?options?
::tclutils::tucomm::files aFile bFile ?options?
::tclutils::tucomm::formatColumns comparison ?-separator sep?
```

## Options

```text
-sort boolean      sort the inputs before comparing
-nocase boolean    compare case-insensitively
```

By default, `tucomm` expects sorted inputs, like Unix `comm`.
