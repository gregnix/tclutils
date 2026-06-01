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
