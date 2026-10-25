# tclutils::tustrings

` tclutils::tustrings ` extracts printable ASCII strings from binary data.

## Load

```tcl
package require tclutils::tustrings
```

## Commands

```tcl
::tclutils::tustrings::extract data ?options?
::tclutils::tustrings::file filename ?options?
```

## Options

- `-minlength n`, default `4`, a positive integer

There is no `-encoding` option: printable means the bytes 32..126. The
data must be bytes (every character 0..255).

## Errors

```text
{TCLUTILS COMMON OPTION -name}        unknown option, option without value
{TCLUTILS COMMON INTEGER -minlength}  -minlength not a positive integer
{TCLUTILS TUSTRINGS BYTES}            data contains a character above 255
```

## Example

```tcl
set strings [::tclutils::tustrings::file test.pdf -minlength 6]
```
