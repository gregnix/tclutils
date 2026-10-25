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

- `-width n`, default `16`, a positive integer
- `-offset n`, default `0`, zero or greater
- `-length n`, default `-1`; a negative value means all remaining bytes

The data must be bytes (every character 0..255); convert text with
`encoding convertto` first.

## Errors

```text
{TCLUTILS COMMON OPTION -name}     unknown option, option without value
{TCLUTILS COMMON INTEGER -width}   -width not a positive integer
{TCLUTILS TUHEXDUMP OFFSET}        -offset negative or not an integer
{TCLUTILS TUHEXDUMP LENGTH}        -length not an integer
{TCLUTILS TUHEXDUMP BYTES}         data contains a character above 255
```

## Example

```tcl
puts [::tclutils::tuhexdump::file test.pdf -length 256]
```
