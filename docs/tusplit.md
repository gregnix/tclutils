# tclutils::tusplit

Split files or strings into smaller parts.

## Load

```tcl
package require tclutils::tusplit
```

## Line splitting

```tcl
set files [::tclutils::tusplit::file input.txt -lines 1000 -outdir parts -prefix part -suffix .txt]
```

## Byte splitting

```tcl
set files [::tclutils::tusplit::file input.bin -bytes 1048576 -outdir parts -prefix chunk]
```

## Commands

- `splitLines text ?options?`
- `splitBytes data ?options?`
- `file path ?options?`
- `lines path n ?options?`
- `bytes path n ?options?`

Options include `-lines`, `-bytes`, `-prefix`, `-suffix`, `-outdir`, and `-digits`.
