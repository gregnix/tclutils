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

## Graphemes and printable characters (0.2)

```tcl
tustr::graphemes "e\u0301x"     ;# -> 2 items: e+accent, x
llength [tustr::graphemes $s]   ;# visible length, unlike [string length]
tustr::isPrintable $char        ;# 0 for C0/C1 controls and DEL, else 1
```

`graphemes` splits a string into user-perceived characters, a simplified
form of UAX #29: a base keeps its combining marks, variation selectors,
skin-tone modifiers and emoji tag characters; ZWJ sequences, flag pairs
(two regional indicators) and CR LF stay together. Hangul syllable
composition and Indic conjuncts are not covered. `[join [graphemes $s] ""]`
gives back `$s`.

Under Tcl 8.6 a character beyond U+FFFF (emoji, flags) comes from a channel
as two surrogates; both commands join the pair first, so 8.6 and 9 give the
same result.

`isPrintable` takes exactly one character (a surrogate pair counts as one)
and raises `{TCLUTILS TUSTR ARG}` otherwise. U+00A0 counts as printable.
