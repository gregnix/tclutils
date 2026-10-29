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

Options include `-regexp`, `-keepmatch`, `-prefix`, `-suffix`, `-outdir`, `-digits`, `-empty` and `-encoding`.

Defaults:

```text
-regexp 1      pattern is a regular expression (0: string match)
-keepmatch 1   the matching line starts the new part
-empty 0       do not write empty parts
-prefix xx     parts are named xx00, xx01, ...
-suffix ""     no suffix
-digits 2      digits of the running number
-outdir .      target directory, created if missing
-encoding utf-8  encoding of the parts; file reads in it too
```

Every line keeps its line end, so the parts put together give the input
again, as with `csplit` (0.2; 0.1 ended each part without `\n`). With
`-keepmatch 0` the matching lines are left out. `file` reads the bytes in
`-encoding` and keeps CRLF; a pattern is matched against the line without
its line end. An unknown encoding raises `TCLUTILS TUCSPLIT ENCODING name`.
