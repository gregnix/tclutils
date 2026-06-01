# tclutils::tuhexdump

` tclutils::tuhexdump ` creates a classic hex/ascii dump from data or files.

## Load

```tcl
package require tclutils::tuhexdump
```

## Commands

```tcl
::tclutils::tuhexdump::data data ?options?
::tclutils::tuhexdump::file filename ?options?
```

## Options

- `-width n`, default `16`
- `-offset n`, default `0`
- `-length n`, default `-1` for all remaining bytes

## Example

```tcl
puts [::tclutils::tuhexdump::file test.pdf -length 256]
```
