# tclutils::tuvalidate

Small format/type validation predicates. Each returns a boolean `1`/`0` and
never throws on the value being checked (only on bad *arguments*, e.g. a
non-integer bound). Pure Tcl, no dependencies.

```tcl
tuvalidate::email   $s            ;# pragmatic email shape
tuvalidate::url     $s            ;# http/https URL
tuvalidate::ipv4    $s            ;# dotted quad, each octet 0..255
tuvalidate::port    $s            ;# integer 1..65535
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
Bad arguments raise `{TCLUTILS TUVALIDATE ARG}` (length) or
`{TCLUTILS TUVALIDATE REGEX}` (pattern).
