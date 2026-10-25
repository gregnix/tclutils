# tclutils::tupaste

` tclutils::tupaste ` combines line streams side by side, similar to Unix
`paste`.

## Load

```tcl
package require tclutils::tupaste 0.2
```

## Examples

```tcl
::tclutils::tupaste::texts [list "a\nb\n" "1\n2\n"] -delimiter ";"
# -> a;1
# -> b;2

::tclutils::tupaste::files [list names.txt cities.txt] -delimiter ";"
```

`-delimiter` (default: tab) goes between the columns; it may be several
characters or empty. If one input is shorter than the others, empty fields are
used. The result has no trailing newline.

An unknown option or an option without value raises
`TCLUTILS COMMON OPTION -name`.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tupaste::lines lineLists args                  ;# merge several column lists row-by-row into delimited lines (like paste); -delimiter
```
