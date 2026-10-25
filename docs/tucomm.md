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
package require tclutils::tucomm 0.2

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
-sort boolean      sort the inputs before comparing (default 0)
-nocase boolean    compare case-insensitively (default 0)
-separator s       formatColumns only: indent per column (default: tab)
```

By default, `tucomm` expects sorted inputs, like Unix `comm`. The comparison
is a merge using `string compare` (with `-nocase 1` on the lower-cased line),
that is code-point order like `comm` and `sort` in the C locale. `-sort 1`
sorts both inputs in exactly that order (plain `lsort`, with `-nocase 1` by
the lower-cased line), so equal lines always end up in `both`, also with
digits or mixed case:

```tcl
::tclutils::tucomm::compareLines {a9 a10} {a10} -sort 1
# -> onlyA a9 onlyB {} both a10
```

Unsorted input without `-sort 1` gives a wrong result without an error.

`formatColumns` writes the groups one after the other: first all `onlyA`
lines without indent, then all `onlyB` lines with one separator, then all
`both` lines with two separators. Unlike `comm`, the three groups are not
merged into one sorted sequence. There is no trailing newline.
