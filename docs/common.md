# tclutils::common

Internal shared helper package for `tclutils`.

This package is not meant as the main public API, but it keeps common behavior
consistent across modules.

## Commands

```tcl
::tclutils::common::readFile path
::tclutils::common::readBinaryFile path
::tclutils::common::writeFile path data ?mode?
::tclutils::common::splitLines text
::tclutils::common::splitDelimited line delimiter
::tclutils::common::parseOptions defaults ?option value ...?
```

## File I/O

The file helpers use Tcl 8.6 `try ... finally`, so opened channels are closed
again even if `read`, `write`, or later processing fails.

`readBinaryFile` explicitly configures binary translation and uses `iso8859-1` as byte-preserving channel encoding.
This avoids the removed Tcl 9 channel encoding name `binary` and still preserves byte values for modules such as `tustrings`, `tuhexdump`, `tubase64`, and `tuzip`.

## Delimited text

`splitDelimited` supports both one-character and multi-character delimiters.
It is used by `tucut` and `tujoin`, replacing duplicated private `_split`
implementations.

## Additional exported commands

Documented for completeness (same module, also covered by the test suite):

```tcl
common::ensureBoolean value optionName         ;# return the canonical boolean for VALUE, or throw an OPTION error naming OPTIONNAME
common::ensurePositiveInteger value what       ;# return VALUE if it is a positive integer, else throw an error naming WHAT
common::ensureOneOf value allowed what         ;# return VALUE if it is in ALLOWED, else an error listing ALLOWED (0.2)
```

## Messages name the way out (0.2)

An unknown option or value is reported together with what would have been
accepted, so the reader does not have to open the source:

```
unknown option "-typ"                 unknown document type: quatsch
Known: -type -timeout                 Known: invoice delivery_note warranty
```

`parseOptions` does this for options, `ensureOneOf` for enumerated values
(errorcode `{TCLUTILS COMMON VALUE <what>}`). The errorcodes of
`parseOptions` are unchanged from 0.1.
