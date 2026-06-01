# tclutils::tuwc

` tclutils::tuwc ` counts lines, words, characters and bytes.

## Load

```tcl
package require tclutils::tuwc
```

## Commands

```tcl
::tclutils::tuwc::text data
::tclutils::tuwc::file filename
```

## Result

Both commands return a dictionary:

```tcl
lines 10 words 42 chars 180 bytes 190
```

The `file` command additionally adds the key `file`.
