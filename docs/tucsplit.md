# tclutils::tucsplit

Split text files by content markers, similar in spirit to `csplit`.

## Load

```tcl
package require tclutils::tucsplit
```

## Example

```tcl
set files [::tclutils::tucsplit::file handbook.md {^# } -outdir chapters -prefix chapter -suffix .md]
```

By default, a matching line starts the next part and is kept in that part.

## Commands

- `splitText text pattern ?options?`
- `file path pattern ?options?`

Options include `-regexp`, `-keepmatch`, `-prefix`, `-suffix`, `-outdir`, `-digits`, and `-empty`.

Defaults:

```text
-regexp 1      pattern is a regular expression (0: string match)
-keepmatch 1   the matching line starts the new part
-empty 0       do not write empty parts
-prefix xx     parts are named xx00, xx01, ...
-suffix ""     no suffix
-digits 2      digits of the running number
-outdir .      target directory, created if missing
```
