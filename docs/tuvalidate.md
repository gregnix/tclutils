# tclutils::tuvalidate

Small format/type validation predicates. Each returns a boolean `1`/`0` and
never throws on the value being checked (only on bad *arguments*, e.g. a
non-integer bound). Pure Tcl, no dependencies.

```tcl
tuvalidate::email   $s            ;# pragmatic email shape
tuvalidate::url     $s            ;# http/https URL
tuvalidate::ipv4    $s            ;# dotted quad, octets 0..255, no leading zeros
tuvalidate::port    $s            ;# decimal digits only, value 1..65535
tuvalidate::alpha   $s            ;# ^[A-Za-z]+$   (ASCII)
tuvalidate::alnum   $s            ;# ^[A-Za-z0-9]+$
tuvalidate::numeric $s            ;# [string is double -strict]
tuvalidate::integer $s            ;# [string is integer -strict]
tuvalidate::length  $s $min $max  ;# min <= length <= max
tuvalidate::pattern $s $regex     ;# regexp match
tuvalidate::inList  $s $list      ;# membership
```

These are pragmatic checks, not full RFC validators -- `email`/`url` accept the
common shapes and reject the obviously broken ones. For Unicode letter classes
use the core `[string is alpha]`; `alpha`/`alnum` here are ASCII-only by design.

`ipv4` is strict like `inet_pton`: exactly four octets of ASCII digits,
each `0`..`255` and without leading zeros (`010.0.0.1` gives 0, `0.0.0.0`
gives 1), no surrounding whitespace.

`port` accepts ASCII decimal digits only -- no sign, no whitespace, no
`0x` prefix. Leading zeros are allowed and read as decimal (`080` is port
80), the value must be `1`..`65535`. `0x50` and `" 80"` give 0. The result
is the same under Tcl 8.6 and 9.

Bad arguments raise `{TCLUTILS TUVALIDATE ARG}` (length) or
`{TCLUTILS TUVALIDATE REGEX}` (pattern).
