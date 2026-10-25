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

`data` and `file` check `-format` and `-address` before the first byte,
so a wrong value is reported also for empty data. The data must be bytes
(every character 0..255).

## Errors

```text
{TCLUTILS TUOD FORMAT value}    unknown -format
{TCLUTILS TUOD ADDRESS value}   unknown -address
{TCLUTILS TUOD WIDTH}           -width not a positive integer
{TCLUTILS TUOD OFFSET}          -offset negative or not an integer
{TCLUTILS TUOD LENGTH}          -length not an integer
{TCLUTILS TUOD BYTES}           data contains a character above 255
{TCLUTILS COMMON OPTION -name}  unknown option, option without value
```
