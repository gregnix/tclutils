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
tustr::slugify "Jörg Müller"            ;# -> joerg-mueller
tustr::capitalize $s
tustr::count $s $sub                    ;# non-overlapping occurrences
```

`padLeft`/`padRight`/`center`/`truncate` take a non-negative integer width/length
(`{TCLUTILS TUSTR ARG}` otherwise). `char` should be a single character.
`toCamel` and `toSnake` treat letters of every script as letters
(`Jörg Müller` -> `jörgMüller`, `JörgMüller` -> `jörg_müller`). `slugify`
returns ASCII for file names and URLs: Latin letters are spelled in ASCII
first (`ä` -> `ae`, `ö` -> `oe`, `ü` -> `ue`, `ß` -> `ss`, accents dropped:
`é` -> `e`, `ł` -> `l`), then every run of other characters becomes one
`-`; what has no ASCII form (`日本`) is dropped (0.3; 0.2 dropped every
non-ASCII letter, `Jörg` gave `j-rg`, and `toCamel` gave `jRgMLler`).

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
