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

- `-minlength n`, default `4`

## Example

```tcl
set strings [::tclutils::tustrings::file test.pdf -minlength 6]
```
