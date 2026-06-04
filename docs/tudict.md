# tclutils::tudict

Dict helpers beyond the Tcl core. Pure Tcl, no dependencies.

The core already does nested access and glob filtering natively -- use those, do
not wrap them:

```tcl
dict get    $d a b c          ;# nested get
dict set    var a b c $value  ;# nested set
dict exists $d a b c          ;# nested existence
dict filter $d key <pattern>  ;# (and: value <pattern>)
```

`tudict` adds only what the core lacks:

```tcl
tudict::getOr $d $default k ?k ...?   ;# nested get, default if path missing
tudict::paths $d                      ;# list of leaf key-paths
tudict::flatten $d ?sep?              ;# {a {b {c 1}}} -> {a.b.c 1}
tudict::mergeDeep $d1 $d2 ?...?       ;# recursive merge (core merge is shallow)
tudict::invert $d                     ;# swap keys/values
```

`getOr` with no key path raises `{TCLUTILS TUDICT ARG}`. Because Tcl cannot truly
distinguish a dict from a string, `paths`/`flatten`/`mergeDeep` use a heuristic
(a non-empty, even-length list is treated as a sub-dict); a scalar that looks
like an even-length list (e.g. `"a b"`) may be seen as a dict.
