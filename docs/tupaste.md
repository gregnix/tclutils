# tclutils::tupaste

` tclutils::tupaste ` combines line streams side by side, similar to Unix
`paste`.

## Load

```tcl
package require tclutils::tupaste
```

## Examples

```tcl
::tclutils::tupaste::texts [list "a\nb\n" "1\n2\n"] -delimiter ";"
# -> a;1
# -> b;2

::tclutils::tupaste::files [list names.txt cities.txt] -delimiter ";"
```

If one input is shorter than the others, empty fields are used.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tupaste::lines lineLists args                  ;# merge several column lists row-by-row into delimited lines (like paste); -delimiter
```
