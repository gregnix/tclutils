# tclutils::tuod

`tuod` provides small `od`-like binary dump helpers in pure Tcl.

```tcl
package require tclutils::tuod

puts [::tclutils::tuod::file test.bin]
puts [::tclutils::tuod::data $bytes -format hex -width 16]
```

## Commands

```tcl
::tclutils::tuod::bytes data ?options?
::tclutils::tuod::data data ?options?
::tclutils::tuod::file filename ?options?
```

## Options

```text
-format   octal|hex|decimal|char   default: octal
-width    number                    default: 16
-offset   number                    default: 0
-length   number                    default: -1
-address  hex|octal|decimal|none    default: hex
```

`bytes` returns unsigned byte values. This avoids Tcl's signed-byte pitfall when using `binary scan` with `c`.
