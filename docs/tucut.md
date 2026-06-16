# tclutils::tucut

` tclutils::tucut ` provides small cut-like helpers for simple delimited text.
It is not a full CSV parser. For quoted CSV data use a CSV package.

## Load

```tcl
package require tclutils::tucut
```

## Examples

```tcl
::tclutils::tucut::field "a;b;c" ";" 2
# -> b

::tclutils::tucut::fields "a;b;c;d" ";" {1 3}
# -> a;c

::tclutils::tucut::text $text -delimiter ";" -fields {1 3}

::tclutils::tucut::file kunden.csv -delimiter ";" -fields {1 3 5}
```

Field numbers are 1-based. Simple ranges like `2-4` are supported.
## 0.24.0

Character selection is available through `tclutils::tucut::chars` and the `-chars` option. Supported specs include single positions, closed ranges like `2-4`, and open ranges like `4-` or `-3`. Character positions are 1-based.


## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tucut::line line args                          ;# extract fields or characters from a single LINE; -fields/-chars -delimiter -joiner
```
