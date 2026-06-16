# tclutils::tustr

String helpers the Tcl core does not provide directly. Pure Tcl, no
dependencies. For what the core already does well, use that instead
(`string reverse`, `string map`, `string repeat`, ...).

```tcl
tustr::isEmpty $s
tustr::truncate $s 20 ?ellipsis?        ;# append ellipsis if longer
tustr::padLeft $s $w ?char?             ;# also padRight, center
tustr::startsWith $s $prefix            ;# also endsWith
tustr::removePrefix $s $prefix          ;# also removeSuffix
tustr::splitTrim $s ?sep?               ;# split, trim, drop empties
tustr::toCamel "my-cool_var"            ;# -> myCoolVar
tustr::toSnake "myCoolVar"              ;# -> my_cool_var
tustr::slugify "Hello, World!"          ;# -> hello-world (ASCII)
tustr::capitalize $s
tustr::count $s $sub                    ;# non-overlapping occurrences
```

`padLeft`/`padRight`/`center`/`truncate` take a non-negative integer width/length
(`{TCLUTILS TUSTR ARG}` otherwise). `char` should be a single character.
`slugify`/`toSnake`/`toCamel` operate on the ASCII alphanumerics in the input.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
tustr::endsWith s suffix                       ;# true if S ends with SUFFIX
tustr::removeSuffix s suffix                   ;# return S without a trailing SUFFIX (unchanged if absent)
```
